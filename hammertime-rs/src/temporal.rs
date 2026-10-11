//! Temporal variable tracking with rewind capability
//! and adaptive logic mutation (FunctionSwapper + RealityFork).

use parking_lot::RwLock;
use std::collections::VecDeque;
use tracing::{debug, info};

/// Tracks a value over time with limited history and rewind.
pub struct TimeVariable<T: Clone> {
    current: RwLock<T>,
    history: RwLock<VecDeque<T>>,
    max_size: usize,
}

impl<T: Clone + std::fmt::Debug> TimeVariable<T> {
    pub fn new(initial: T, max_size: usize) -> Self {
        let mut hist = VecDeque::with_capacity(max_size);
        hist.push_back(initial.clone());
        Self {
            current: RwLock::new(initial),
            history: RwLock::new(hist),
            max_size,
        }
    }

    pub fn set(&self, value: T) {
        let mut hist = self.history.write();
        hist.push_back(value.clone());
        if hist.len() > self.max_size {
            hist.pop_front();
        }
        *self.current.write() = value;
    }

    pub fn get(&self) -> T {
        self.current.read().clone()
    }

    /// Rewind by `steps` (default 1). Returns the restored value.
    pub fn rewind(&self, steps: usize) -> T {
        let hist = self.history.read();
        let idx = hist.len().saturating_sub(steps + 1);
        let restored = hist.get(idx).cloned().unwrap_or_else(|| self.get());
        drop(hist);
        *self.current.write() = restored.clone();
        info!("🔄 Rewound value to: {:?}", restored);
        restored
    }

    pub fn history_len(&self) -> usize {
        self.history.read().len()
    }
}

/// Mutable defensive logic that can be swapped at runtime.
pub struct FunctionSwapper {
    logic: RwLock<Box<dyn Fn() + Send + Sync>>,
}

impl FunctionSwapper {
    pub fn new<F>(initial: F) -> Self
    where
        F: Fn() + Send + Sync + 'static,
    {
        Self {
            logic: RwLock::new(Box::new(initial)),
        }
    }

    pub fn run(&self) {
        (self.logic.read())();
    }

    pub fn mutate<F>(&self, new_logic: F)
    where
        F: Fn() + Send + Sync + 'static,
    {
        *self.logic.write() = Box::new(new_logic);
        info!("🛠️  Logic mutated!");
    }
}

/// Multi-timeline execution (RealityFork).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Timeline {
    Alpha,
    Beta,
    Omega,
}

impl Timeline {
    pub fn as_str(&self) -> &'static str {
        match self {
            Timeline::Alpha => "alpha",
            Timeline::Beta => "beta",
            Timeline::Omega => "omega",
        }
    }
}

pub struct RealityFork {
    current: RwLock<Timeline>,
    branches: RwLock<std::collections::HashMap<Timeline, Box<dyn Fn() + Send + Sync>>>,
}

impl RealityFork {
    pub fn new() -> Self {
        let mut map = std::collections::HashMap::new();
        map.insert(
            Timeline::Alpha,
            Box::new(|| info!("🌱 Alpha Fork: Normalized behavior profile."))
                as Box<dyn Fn() + Send + Sync>,
        );
        map.insert(
            Timeline::Omega,
            Box::new(|| info!("🔥 Omega Fork: Polymorphic logic running…"))
                as Box<dyn Fn() + Send + Sync>,
        );
        Self {
            current: RwLock::new(Timeline::Alpha),
            branches: RwLock::new(map),
        }
    }

    pub fn register<F>(&self, timeline: Timeline, logic: F)
    where
        F: Fn() + Send + Sync + 'static,
    {
        self.branches.write().insert(timeline, Box::new(logic));
    }

    pub fn switch_to(&self, timeline: Timeline) {
        *self.current.write() = timeline;
        info!("🌐 Timeline switched to: {}", timeline.as_str());
    }

    pub fn current(&self) -> Timeline {
        *self.current.read()
    }

    pub fn run(&self) {
        let current = self.current();
        debug!("🧪 Executing timeline: {}", current.as_str());
        if let Some(branch) = self.branches.read().get(&current) {
            branch();
        } else {
            tracing::warn!("No logic registered for timeline: {}", current.as_str());
        }
    }
}

impl Default for RealityFork {
    fn default() -> Self {
        Self::new()
    }
}
