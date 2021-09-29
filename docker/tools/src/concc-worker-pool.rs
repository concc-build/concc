use anyhow::{anyhow, Result};
use fs2::FileExt;
use std::fs::File;
use std::path::{Path, PathBuf};
use serde::{Deserialize, Serialize};
use serde_json;
use structopt::StructOpt;

#[derive(Debug, StructOpt)]
struct Opt {
    #[structopt(long, env = "CONCC_DIR", parse(from_os_str))]
    dir: PathBuf,

    #[structopt(subcommand)]
    cmd: Cmd,
}

#[derive(Debug, StructOpt)]
enum Cmd {
    Status,
    Reset,
    Add {
        host: String,
        limit: usize,
    },
    Remove {
        host: String,
    },
    Allocate,
    Release {
        host: String,
    },
    Limit,
}

fn main() -> Result<()> {
    let opt = Opt::from_args();
    match opt.cmd {
        Cmd::Status => status(&opt.dir),
        Cmd::Reset => reset(&opt.dir),
        Cmd::Add { ref host, limit } => add(&opt.dir, host, limit),
        Cmd::Remove { ref host } => remove(&opt.dir, host),
        Cmd::Allocate => allocate(&opt.dir),
        Cmd::Release { ref host } => release(&opt.dir, host),
        Cmd::Limit => limit(&opt.dir),
    }
}

fn status(dir: &Path) -> Result<()> {
    let _lock = Lock::new(dir)?;
    let json = dir.join("workers.json");
    let data = std::fs::read_to_string(&json)?;
    println!("{}", data);
    Ok(())
}

fn reset(dir: &Path) -> Result<()> {
    let _lock = Lock::new(dir)?;
    let json = dir.join("workers.json");
    std::fs::write(&json, "[]")?;
    Ok(())
}

fn add(dir: &Path, host: &str, limit: usize) -> Result<()> {
    let _lock = Lock::new(dir)?;
    let json = dir.join("workers.json");
    let data = std::fs::read_to_string(&json)?;
    let mut workers: Vec<WorkerEntry> = serde_json::from_str(&data)?;
    if workers.iter().any(|worker| worker.host == host) {
        Err(anyhow!("Already exists: {}", host))
    } else {
        workers.push(WorkerEntry::new(host, limit));
        std::fs::write(&json, serde_json::to_string(&workers)?)?;
        Ok(())
    }
}

fn remove(dir: &Path, host: &str) -> Result<()> {
    let _lock = Lock::new(dir)?;
    let json = dir.join("workers.json");
    let data = std::fs::read_to_string(&json)?;
    let workers: Vec<WorkerEntry> = serde_json::from_str(&data)?;
    let workers: Vec<WorkerEntry> = workers.into_iter()
        .filter(|worker| worker.host != host)
        .collect();
    std::fs::write(&json, serde_json::to_string(&workers)?)?;
    Ok(())
}

fn allocate(dir: &Path) -> Result<()> {
    let _lock = Lock::new(dir)?;
    let json = dir.join("workers.json");
    let data = std::fs::read_to_string(&json)?;
    let mut workers: Vec<WorkerEntry> = serde_json::from_str(&data)?;
    let host = match workers.iter_mut()
        .max_by_key(|worker| worker.limit - worker.count) {
            Some(worker) if worker.count < worker.limit => {
                worker.count += 1;
                worker.host.clone()
            }
            _ => {
                // No available worker in pool.
                return Ok(());
            }
        };
    std::fs::write(&json, serde_json::to_string(&workers)?)?;
    println!("{}", host);
    Ok(())
}

fn release(dir: &Path, host: &str) -> Result<()> {
    let _lock = Lock::new(dir)?;
    let json = dir.join("workers.json");
    let data = std::fs::read_to_string(&json)?;
    let mut workers: Vec<WorkerEntry> = serde_json::from_str(&data)?;
    match workers.iter_mut().find(|worker| worker.host == host) {
        Some(worker) => {
            if worker.count <= 0 {
                return Err(anyhow!("Counter underflow: {}", host));
            }
            worker.count -= 1;
        }
        _ => return Err(anyhow!("No such worker in pool: {}", host)),
    }
    std::fs::write(&json, serde_json::to_string(&workers)?)?;
    Ok(())
}

fn limit(dir: &Path) -> Result<()> {
    let _lock = Lock::new(dir)?;
    let json = dir.join("workers.json");
    let data = std::fs::read_to_string(&json)?;
    let workers: Vec<WorkerEntry> = serde_json::from_str(&data)?;
    let limit: usize = workers.iter().map(|worker| worker.limit).sum();
    println!("{}", limit);
    Ok(())
}

struct Lock(File);

impl Lock {
    fn new(dir: &Path) -> Result<Self> {
        let lockfile = dir.join("workers.lock");
        let file = std::fs::File::create(lockfile)?;
        file.lock_exclusive()?;
        Ok(Lock(file))
    }
}

#[derive(Deserialize, Serialize)]
struct WorkerEntry {
    host: String,
    limit: usize,
    count: usize,
}

impl WorkerEntry {
    fn new(host: &str, limit: usize) -> Self {
        WorkerEntry {
            host: host.to_string(),
            limit,
            count: 0,
        }
    }
}
