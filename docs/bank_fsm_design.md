# DDR3 Bank FSM - Design Document

**Author:** Cameron Callahan
**Date:** January 10, 2026
**Status:** Complete and Partially Verified

---

## 1. Overview

The Bank FSM manages a single DDR3 bank, handling row activation, timing enforcement, and row buffer optimization.

### Key Responsibilities
- Issue ACTIVATE, READ, WRITE, and PRECHARGE commands
- Enforce DDR3 timing parameters (tRCD, tRAS, tRP)
- Track open row for hit/miss detection
- Optimize performance through row buffer management

---

## 2. Interface

### Inputs
| Signal | Width | Description |
|--------|-------|-------------|
| `clk` | 1 | System clock (100 MHz) |
| `rst_n` | 1 | Active-low async reset |
| `user_req_valid` | 1 | Request valid from user |
| `req_rnw` | 1 | Read (1) or Write (0) |
| `req_row` | 13 | Row address |
| `req_col` | 10 | Column address |

### Outputs
| Signal | Width | Description |
|--------|-------|-------------|
| `user_req_ready` | 1 | FSM ready to accept request |
| `cmd_valid` | 1 | Command valid to cmd_gen |
| `cmd_type` | 3 | Command type (ACTIVATE, READ, etc.) |
| `cmd_addr` | 13 | Address for command |
| `state` | 3 | Current FSM state (for monitoring) |
| `busy` | 1 | Bank is busy |

---

## 3. State Machine

### States
```
     ┌─────────────┐
     │    IDLE     │ ← No row open, ready for requests
     └──────┬──────┘
            │ user_req_valid || pending_req
            ↓
     ┌─────────────┐
     │ ACTIVATING  │ ← Wait tRCD (6 cycles)
     └──────┬──────┘
            │ trcd_met
            ↓
     ┌─────────────┐
     │   ACTIVE    │ ← Row open, process requests
     └──────┬──────┘
            │ row_miss && tras_met
            ↓
     ┌─────────────┐
     │PRECHARGING  │ ← Wait tRP (6 cycles)
     └──────┬──────┘
            │ trp_met
            └────────► (back to IDLE)
```

### State Descriptions

**IDLE:**
- No row open
- Ready to accept new requests
- Issues ACTIVATE command for new requests
- Resumes pending requests after row miss

**ACTIVATING:**
- ACTIVATE command issued
- Waiting tRCD (6 cycles) before row is accessible
- Counter: `trcd_counter` counts down from 6 to 0

**ACTIVE:**
- Row is open and accessible
- Can issue READ/WRITE commands
- Detects row hits (same row) and misses (different row)
- Row hit: Issue command immediately (fast path)
- Row miss: Issue PRECHARGE, transition to PRECHARGING
- Counter: `tRAS_counter` counts up from 0 to 15

**PRECHARGING:**
- PRECHARGE command issued
- Waiting tRP (6 cycles) before row is fully closed
- Counter: `trp_counter` counts down from 6 to 0

---

## 4. Timing Parameters

| Parameter | Cycles | Time @ 100MHz | Description |
|-----------|--------|---------------|-------------|
| tRCD | 6 | 60 ns | RAS to CAS delay |
| tRAS | 15 | 150 ns | Row active time (minimum) |
| tRP | 6 | 60 ns | Precharge time |

**Timing Enforcement:**
- `trcd_counter`: Counts down during ACTIVATING
- `tras_counter`: Counts up during ACTIVATING + ACTIVE
- `trp_counter`: Counts down during PRECHARGING

---

## 5. Row Buffer Optimization

### Row Hit (Fast Path)
When a request targets the currently open row:
- **No ACTIVATE needed**
- **Direct READ/WRITE** (2 cycles total)
- **~4.5x faster** than first access

### Row Miss (Slow Path)
When a request targets a different row:
1. Detect row mismatch
2. Issue PRECHARGE (close current row)
3. Wait tRP (6 cycles)
4. Issue ACTIVATE (open new row)
5. Wait tRCD (6 cycles)
6. Issue READ/WRITE
7. **Total: ~18 cycles**

### Performance Impact
- **First access:** 9 cycles (ACTIVATE + tRCD + READ)
- **Row hit:** 2 cycles (immediate READ)
- **Row miss:** 18 cycles (PRECHARGE + tRP + ACTIVATE + tRCD + READ)

---

## 6. Request Handling

### Request Latching
Requests are captured in internal registers when accepted:
- `my_req_row`: Latched row address
- `my_req_col`: Latched column address
- `my_rnw`: Latched read/write flag
- `pending_req`: Flag indicating request in progress

**Why?** Input signals may change after handshake completes. Latching ensures FSM operates on stable data.

### Pending Request Resume
When a row miss occurs:
1. Request is latched but not completed
2. PRECHARGE → IDLE transition occurs
3. `pending_req` flag remains set
4. IDLE state checks `pending_req` and resumes
5. Issues ACTIVATE for the pending request's row
6. Completes the request in ACTIVE state

---

## 7. Key Design Decisions

### Decision 1: Latch Requests Immediately
**Why:** Testbench may change input signals after handshake. Latching ensures data integrity.

### Decision 2: Stay in ACTIVE After Request
**Why:** Keeping row open enables fast row hits. Only precharge when necessary (row miss or power management).

### Decision 3: Use `req_row` for ACTIVATE Address
**Why:** For new requests, `my_req_row` isn't updated yet (timing). For pending requests, use `my_req_row`.

**Implementation:**
```systemverilog
cmd_addr = pending_req ? my_req_row : req_row;
```

### Decision 4: Clear `open_row` on PRECHARGE
**Why:** After precharge, no row is open. Clearing prevents false row hits.

---

## 8. Future Enhancements

- [ ] Power-down state with timeout
- [ ] Multiple pending requests (queue)
- [ ] Command pipelining
- [ ] Priority arbitration
- [ ] Performance counters

---

## 9. Files

- **RTL:** `rtl/ddr3_bank_fsm.sv`
- **Definitions:** `rtl/ddr3_defs.svh`
- **Testbench:** `tb/tb_bank_fsm.sv`
- **Simulation:** `sim/run_files/fsm_run_gui.do`

---

## 10. References

- JEDEC DDR3 SDRAM Specification (JESD79-3F)
- Micron DDR3 SDRAM Datasheet