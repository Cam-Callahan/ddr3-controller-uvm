Ddr3 basics · MD
Copy

# DDR3 SDRAM Basics - Quick Reference

## What is DDR3?

**DDR3 (Double Data Rate 3) SDRAM** is a type of synchronous dynamic random-access memory. It transfers data on both the rising and falling edges of the clock signal, achieving double the data rate of SDR (Single Data Rate) memory.

---

## Key Concepts

### 1. Bank Architecture

DDR3 is organized into **banks** - independent memory arrays that can operate concurrently.

```
┌──────────────────────────────────────┐
│          DDR3 DRAM Chip              │
│  ┌─────────┐  ┌─────────┐           │
│  │ Bank 0  │  │ Bank 1  │  ...      │
│  │ (Array) │  │ (Array) │           │
│  └─────────┘  └─────────┘           │
│                                      │
│  Each bank has:                      │
│    - Rows (activated one at a time)  │
│    - Columns (accessed within row)   │
│    - Sense amplifiers (row buffer)   │
└──────────────────────────────────────┘
```

**Why banks?**
- Allows **parallel operations** (read from Bank 0 while activating Bank 1)
- Hides **row precharge/activate latency**
- Increases **effective throughput**

**Our Design:** 4 banks (simplified from 8)

---

### 2. Row/Column Addressing

Memory is addressed in **two steps**: Row, then Column.

```
Address Space:
  Bank [1:0]     → Select which of 4 banks
  Row [12:0]     → Select which row in the bank (8,192 rows)
  Column [9:0]   → Select which column in the row (1,024 columns)

Total Capacity:
  4 banks × 8K rows × 1K cols × 8 bits = 256 Mbit (32 MB)
```

**Why two-step addressing?**
- DRAM is a 2D array (capacitor grid)
- Must first **activate a row** (load into sense amplifiers)
- Then **access columns** from that row
- More efficient than providing full address every time

---

### 3. DDR3 Commands

Commands are encoded on the **RAS#, CAS#, WE#** pins.

| Command | RAS# | CAS# | WE# | Purpose |
|---------|------|------|-----|---------|
| **ACTIVATE** | 0 | 1 | 1 | Open a row in a bank |
| **READ** | 1 | 0 | 1 | Read data from active row |
| **WRITE** | 1 | 0 | 0 | Write data to active row |
| **PRECHARGE** | 0 | 1 | 0 | Close row (prepare for new row) |
| **REFRESH** | 0 | 0 | 1 | Refresh DRAM cells |
| **NOP** | 1 | 1 | 1 | No operation |

**# = Active Low** (0 means active)

---

### 4. Bank State Machine

Each bank operates as a state machine:

```
     ┌──────┐
     │ IDLE │  (No row open)
     └───┬──┘
         │ ACTIVATE command
         ↓
  ┌─────────────┐
  │ ACTIVATING  │  (Wait tRCD)
  └──────┬──────┘
         │ tRCD expires
         ↓
     ┌────────┐
     │ ACTIVE │  (Row open, can READ/WRITE)
     └───┬────┘
         │ PRECHARGE command
         ↓
  ┌──────────────┐
  │ PRECHARGING  │  (Wait tRP)
  └───────┬──────┘
          │ tRP expires
          └──────→ Back to IDLE
```

---

### 5. Critical Timing Parameters

DDR3 has **strict timing constraints** between commands.

#### tRCD - RAS to CAS Delay
```
Time from ACTIVATE to READ/WRITE
Why? Row data needs time to propagate to sense amplifiers
Our value: 15ns (6 cycles @ 2.5ns)

  ACTIVATE → [wait tRCD] → READ/WRITE allowed
```

#### tRP - Row Precharge Time
```
Time for PRECHARGE to complete
Why? Bitlines need time to equalize before next activation
Our value: 15ns (6 cycles)

  PRECHARGE → [wait tRP] → ACTIVATE allowed
```

#### tRAS - Row Active Time
```
Minimum time a row must stay open
Why? Ensures sense amplifiers have time to refresh capacitors
Our value: 37.5ns (15 cycles)

  ACTIVATE → [wait min tRAS] → PRECHARGE allowed
```

#### tRC - Row Cycle Time
```
Minimum time between ACTIVATE commands to same bank
Why? tRAS + tRP (full row open/close cycle)
Our value: 52.5ns (21 cycles)

  ACTIVATE → [wait tRC] → ACTIVATE (same bank) allowed
```

#### tREFI - Refresh Interval
```
Maximum time between REFRESH commands
Why? DRAM capacitors leak, need periodic refresh
Value: 7.8μs (3,120 cycles)

  Must issue REFRESH every tREFI or lose data!
```

#### CL - CAS Latency
```
Delay from READ command to data appearing on DQ
Why? Column access and data path delays
Our value: 15ns (6 cycles)

  READ → [wait CL] → Data on DQ
```

---

### 6. Typical Operation Sequence

#### Read from New Row:
```
Cycle  Command      Notes
----   -------      -----
0      ACTIVATE     Bank 0, Row 100 → Load row into sense amps
1-5    NOP          Wait for tRCD (6 cycles)
6      READ         Column 50 → Request data
7-11   NOP          Wait for CAS latency (6 cycles)
12     [Data out]   Data appears on DQ pins
13-18  NOP          Complete burst (BL8 = 8 beats)
19+    PRECHARGE    Close the row (or leave open for next access)
```

**Total latency: ~14 cycles (35ns)** for cold read

#### Read from Open Row (Row Buffer Hit):
```
Cycle  Command      Notes
----   -------      -----
0      READ         Row already open, just access column
1-5    NOP          Wait for CAS latency
6      [Data out]   Much faster! Only ~7 cycles (17.5ns)
```

This is why **page policies** (open vs. closed rows) matter for performance!

---

### 7. Refresh Operation

**Why needed?** DRAM stores data as charge in capacitors. Charge leaks over time, so cells must be refreshed periodically.

**How it works:**
1. Controller must issue **REFRESH** command every tREFI (7.8μs)
2. **All banks must be idle** (precharged) before REFRESH
3. DRAM internally refreshes one row across all banks
4. Takes tRFC (110ns) to complete

**Controller's job:**
- Track time since last refresh
- Precharge any open rows when refresh is due
- Issue REFRESH command
- Wait tRFC before allowing new commands

**Our design:** Simple periodic refresh (no sophisticated scheduling)

---

### 8. Data Strobe (DQS)

DDR3 uses a **data strobe** signal that toggles with data.

#### Reads (Data from DRAM):
```
DQS is edge-aligned with data
        ──┐ ┌─┐ ┌─┐ ┌─┐ ┌──  DQS
          └─┘ └─┘ └─┘ └─┘
    ───┤D0├┤D1├┤D2├┤D3├───  DQ
```
Controller samples DQ on both edges of DQS → Double data rate!

#### Writes (Data to DRAM):
```
DQS is center-aligned with data
    ────┐  ┌───┐  ┌────  DQS
        └──┘   └──┘
    ──────┤ D0 ├────── DQ
```
DRAM samples DQ when DQS toggles

**Our simplification:** Basic DQS, not fully modeling setup/hold timing

---

### 9. Burst Length

DDR3 reads/writes data in **bursts** (multiple consecutive beats).

**Burst Length 8 (BL8):**
- Single READ/WRITE command transfers **8 data beats**
- Each beat is one clock edge (so 4 full clock cycles for BL8)
- Columns auto-increment: Col 0, 1, 2, 3, 4, 5, 6, 7

**Why bursts?**
- Amortizes command overhead
- Matches cache line sizes
- Improves efficiency

**Our design:** Fixed BL8 (no burst chop)

---

### 10. What the Controller Does

**The memory controller's job:**

1. **Bank Management**
   - Track which rows are open in each bank
   - Decide when to precharge (close rows)

2. **Command Scheduling**
   - Translate user requests to DDR3 commands
   - Ensure all timing constraints are met
   - Arbitrate between competing requests

3. **Refresh Management**
   - Track refresh timing
   - Preempt user requests to issue REFRESH

4. **Data Path**
   - Buffer write data until WRITE command
   - Capture read data after CL delay
   - Return data to user

**Key challenge:** Maximize throughput while meeting timing!

---

## DDR3-800 Timing Summary

| Parameter | Cycles | Nanoseconds |
|-----------|--------|-------------|
| tCK (Clock Period) | 1 | 2.5 |
| tRCD | 6 | 15 |
| tRP | 6 | 15 |
| tRAS | 15 | 37.5 |
| tRC | 21 | 52.5 |
| CL | 6 | 15 |
| tREFI | 3,120 | 7,800 |
| tRFC | 44 | 110 |

---

## Common Interview Questions

**Q: Why does DRAM need refresh?**
A: Capacitors leak charge over time. Without refresh, data is lost.

**Q: What's the difference between ACTIVATE and READ?**
A: ACTIVATE opens a row (loads to sense amps). READ accesses a column from the already-open row.

**Q: Why use multiple banks?**
A: Banks allow parallel operations. While one bank is activating, another can be reading. This hides latency and improves throughput.

**Q: What happens if you violate tRCD?**
A: Read/write data would be incorrect because the row hasn't fully propagated to the sense amplifiers yet.

**Q: How would you improve this controller?**
A: Add request reordering, smarter page policies (open-page for sequential access), better refresh scheduling, support for multiple ranks, etc.

---

## Additional Resources

- **Micron DDR3 Datasheet:** Detailed timing diagrams
- **JEDEC JESD79-3F:** Official DDR3 specification
- **Bruce Jacob's "Memory Systems":** Deep dive into DRAM architecture

---

**Last Updated:** [01/02/2026]