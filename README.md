# DDR3 Memory Controller with UVM Verification

A SystemVerilog implementation of a DDR3 SDRAM memory controller with comprehensive UVM-based verification environment.

## 🎯 Project Overview

This project implements a simplified DDR3 memory controller designed to interface with a 1Gb x8 DDR3 SDRAM device. The controller manages bank state machines, enforces timing constraints, and provides a simple request/response interface for read/write operations.

**Target Interview Companies:** AMD, Intel, NVIDIA
**Role:** Design Verification Engineer (Entry-Level)
**Timeline:** 2-4 weeks

## 📊 Key Features

### RTL Design
- **4-bank architecture** with independent FSMs per bank
- **DDR3-800 speed grade** (2.5ns clock period)
- **Command support:** ACTIVATE, READ, WRITE, PRECHARGE, REFRESH
- **Timing enforcement:** tRCD, tRP, tRAS, tRC, tREFI
- **8-bit data interface** (simplified from x4 for ease of verification)
- **Single rank** configuration

### Verification Environment
- **UVM-based testbench** with full verification component hierarchy
- **Functional coverage** for command sequences, bank states, and timing scenarios
- **SystemVerilog Assertions (SVA)** for protocol and timing checks
- **Behavioral DDR3 DRAM model** for closed-loop testing
- **Multiple test scenarios** (random, directed, constrained-random)

## 🏗️ Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                   User Interface                             │
│  (Simple request/response for CPU/system memory access)      │
└────────────────────────┬─────────────────────────────────────┘
                         │
┌────────────────────────▼─────────────────────────────────────┐
│              DDR3 Memory Controller (RTL)                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │  Bank 0 FSM  │  │  Bank 1 FSM  │  │  Bank 2 FSM  │  ...   │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
│  ┌──────────────┐  ┌──────────────┐                          │
│  │ Refresh Ctrl │  │  Cmd Gen     │                          │
│  └──────────────┘  └──────────────┘                          │
└────────────────────────┬─────────────────────────────────────┘
                         │ DDR3 Protocol
                         │ (RAS#, CAS#, WE#, BA, ADDR, DQ, DQS)
                         │
┌────────────────────────▼─────────────────────────────────────┐
│         DDR3 DRAM Behavioral Model (Testbench)               │
│                  1Gb x8 DDR3 SDRAM                           │
└──────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
ddr3-controller-uvm/
├── README.md                    # This file
├── ARCHITECTURE.md              # Detailed design specification
├── TIMELINE.md                  # Development schedule
├── docs/
│   ├── ddr3_basics.md          # DDR3 fundamentals reference
│   ├── timing_diagram.md       # Command timing diagrams
│   └── testplan.md             # Verification test plan
├── rtl/
│   ├── ddr3_controller.sv      # Top-level controller
│   ├── ddr3_bank_fsm.sv        # Per-bank state machine
│   ├── ddr3_cmd_gen.sv         # Command generator
│   ├── ddr3_refresh.sv         # Refresh controller
│   └── ddr3_defs.svh           # Parameter definitions
├── models/
│   └── ddr3_simple_model.sv    # Behavioral DRAM model
├── tb/
│   ├── ddr3_if.sv              # DDR3 interface
│   ├── ddr3_pkg.sv             # UVM package
│   ├── sequences/
│   │   ├── ddr3_sequence_item.sv
│   │   └── ddr3_base_sequence.sv
│   ├── components/
│   │   ├── ddr3_driver.sv
│   │   ├── ddr3_monitor.sv
│   │   ├── ddr3_scoreboard.sv
│   │   ├── ddr3_coverage.sv
│   │   ├── ddr3_agent.sv
│   │   └── ddr3_env.sv
│   ├── tests/
│   │   ├── ddr3_base_test.sv
│   │   └── ddr3_sanity_test.sv
│   └── tb_top.sv
├── sim/
│   ├── Makefile
│   └── run.do                  # ModelSim script
└── scripts/
    └── analyze_coverage.py     # Coverage analysis
```

## 🚀 Getting Started

### Prerequisites
- **ModelSim** (for simulation)
- **SystemVerilog** compiler with UVM support
- **Python 3.x** (for coverage scripts)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/[your-username]/ddr3-controller-uvm.git
cd ddr3-controller-uvm

# Run basic sanity test
cd sim
make sanity

# Run all tests
make all

# View coverage report
make coverage
```

## 📈 Development Phases

### Phase 1: RTL Design (Week 1-2)
- [x] Project planning and architecture
- [ ] Bank FSM implementation
- [ ] Command generator
- [ ] Refresh controller
- [ ] Top-level integration
- [ ] Basic directed testbench

### Phase 2: UVM Testbench (Week 2-3)
- [ ] Interface and package setup
- [ ] Sequence item and sequences
- [ ] Driver and monitor
- [ ] Agent and environment
- [ ] Basic tests
- [ ] Behavioral DRAM model

### Phase 3: Advanced Verification (Week 3-4)
- [ ] Functional coverage
- [ ] SystemVerilog assertions
- [ ] Constrained-random testing
- [ ] Corner case scenarios
- [ ] Documentation and polish

## 🎓 Learning Objectives

This project demonstrates:
1. **RTL Design:** State machines, timing constraints, protocol implementation
2. **Verification Methodology:** UVM testbench architecture
3. **Coverage-Driven Verification:** Functional coverage and assertions
4. **Memory Controller Concepts:** Bank management, refresh, timing enforcement
5. **Industry Best Practices:** Coding standards, documentation, version control

## 📚 References

- **Micron DDR3 SDRAM Datasheet:** MT41J256M4 (1Gb x4)
  - Command encoding (Page 91)
  - State diagram (Page 10)
  - Timing parameters (Page 63)
- **JEDEC Standard:** JESD79-3F (DDR3 SDRAM Specification)
- **UVM Resources:**
  - Ray Salemi's UVM Primer
  - Verification Academy tutorials

## 🎯 Target Specifications

| Parameter | Value | Notes |
|-----------|-------|-------|
| Banks | 4 | Simplified from 8 |
| Row Address | 13 bits | 8K rows |
| Column Address | 10 bits | 1K columns |
| Data Width | 8 bits | Simplified from x4 |
| Clock Period (tCK) | 2.5ns | DDR3-800 |
| tRCD | 15ns (6 cycles) | RAS-to-CAS delay |
| tRP | 15ns (6 cycles) | Precharge time |
| tRAS | 37.5ns (15 cycles) | Row active time |
| tRC | 52.5ns (21 cycles) | Row cycle time |
| tREFI | 7.8μs | Refresh interval |

## 📞 Contact

**Cameron Callahan**
Electrical Engineering Graduate - Texas State University
[camcallahan2001@outlook.com] | [LinkedIn] | [GitHub]

---

**Note:** This is an educational project for demonstrating design verification skills. The simplified architecture focuses on core concepts while remaining practical for a 2-4 week development timeline.