use clap::{App, Arg};
use humantime::parse_duration;
use partial_min_max::max;
use serde::de::{self, Deserializer};
use serde::Deserialize;
use std::error::Error;
use std::process::Command;
use std::{
    fs, iter, thread,
    time::{Duration, Instant},
};
use systemstat::{CPULoad, Platform, System};

#[derive(Deserialize, Debug)]
pub struct Config {
    #[serde(deserialize_with = "deserialize_duration")]
    measurement_interval: Duration,
    #[serde(deserialize_with = "deserialize_duration")]
    window: Duration,
    threshold_cpu_percent: f32,
    command: String,
    #[serde(deserialize_with = "deserialize_duration")]
    cooldown: Duration,
}

fn main() -> Result<(), Box<dyn Error>> {
    let args = App::new("")
        .arg(
            Arg::with_name("config.toml")
                .required(true)
                .help("Sets a custom config file")
                .takes_value(true),
        )
        .get_matches();

    let config_file = args.value_of("config.toml").unwrap();
    let config: Config = toml::from_str(&fs::read_to_string(&config_file)?)
        .map_err(|e| format!("Unable to parse `{}`: {}", config_file, e))?;

    let mut last_executed_cmd: Option<Instant> = None;
    let mut consecutive_measurements_below_threshold = 0;
    for load in cpu_load_forever(config.measurement_interval) {
        if load < config.threshold_cpu_percent {
            // increment the counter if we have low load
            consecutive_measurements_below_threshold += 1;
        } else {
            // reset the counter if we have high load
            consecutive_measurements_below_threshold = 0;
        }

        // have we been continuously idle for a long time?
        let sufficiently_idle = (consecutive_measurements_below_threshold
            * config.measurement_interval)
            >= config.window;
        // have we recently triggered the alarm?
        let not_cooldown = match last_executed_cmd {
            Some(time_ago) => Instant::now() - time_ago > config.cooldown,
            None => true,
        };

        // Okay, print a log and execute the command
        if sufficiently_idle && not_cooldown {
            println!(
                "CPU load below {}% for {:?}. Executing command: '{}'",
                config.threshold_cpu_percent,
                config.window,
                config.command.clone(),
            );

            last_executed_cmd = Some(Instant::now());
            Command::new("/bin/sh")
                .arg("-c")
                .arg(config.command.clone())
                .spawn()?;
        }
    }

    Ok(())
}

fn _cpu_tot_time(cpu: &CPULoad) -> f32 {
    // https://github.com/giampaolo/psutil/blob/6b6f98b3d0926901c0929a377dfd2680b93661c9/psutil/__init__.py#L1645
    return cpu.user + cpu.nice + cpu.system + cpu.interrupt + cpu.idle;
}

fn _cpu_busy_time(cpu: &CPULoad) -> f32 {
    // https://github.com/giampaolo/psutil/blob/6b6f98b3d0926901c0929a377dfd2680b93661c9/psutil/__init__.py#L1664
    return _cpu_tot_time(cpu) - cpu.idle - cpu.platform.iowait;
}

fn cpu_percent(times_delta: &CPULoad) -> f32 {
    // https://github.com/giampaolo/psutil/blob/6b6f98b3d0926901c0929a377dfd2680b93661c9/psutil/__init__.py#L1701
    //let times_delta = _cpu_times_deltas(t1, t2);

    let all_delta = max(_cpu_tot_time(&times_delta), 0.0);
    let busy_delta = max(_cpu_busy_time(&times_delta), 0.0);

    if all_delta == 0.0 {
        return 0.0;
    }
    return busy_delta / all_delta * 100.;
}

fn cpu_load_forever(interval: Duration) -> impl Iterator<Item = f32> {
    let sys = System::new();
    iter::repeat(()).map(move |_nothing| match sys.cpu_load() {
        Ok(cpus) => {
            thread::sleep(interval);
            let load: Vec<f32> = cpus
                .done()
                .unwrap()
                .iter()
                .map(|x| cpu_percent(x))
                .collect();
            let average: f32 = load.iter().sum::<f32>() / (load.len() as f32);
            average
        }
        Err(_x) => f32::NAN,
    })
}

fn deserialize_duration<'de, D>(data: D) -> Result<Duration, D::Error>
where
    D: Deserializer<'de>,
{
    let s: &str = Deserialize::deserialize(data)?;
    parse_duration(s).map_err(de::Error::custom)
}
