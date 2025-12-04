# SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# SPDX-License-Identifier: Apache-2.0

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles


@cocotb.test()
async def test_project(dut):
    """
    Basic VGA timing test for `tt_um_goose` 

    Verifies:
    - During visible area, `hsync` and `vsync` should be low.
    - `hsync` becomes high during the horizontal sync window and
      returns low after the sync period.
    """

    dut._log.info("Start")

    # Clock: 39 ns period keeps simulation fast while representing a clock
    clock = Clock(dut.clk, 39, units="ns")
    cocotb.start_soon(clock.start())

    # Reset sequence (active-low reset)
    dut._log.info("Reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 10)
    dut.rst_n.value = 1

    dut._log.info("Test project behavior")

    # Known inputs for the test
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Skip one full frame to reach stable pipeline state.
    # hvsync_generator timing: visible=640, back=48, front=16, sync=96
    await ClockCycles(dut.clk, 640 + 48 + 16 + 96)

    # During visible region, hsync/vsync should be low
    # uo_out mapping: {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]}
    # -> uo_out[7]=hsync, uo_out[3]=vsync
    assert dut.uo_out[3].value == 0, "vsync should be low during visible area"
    assert dut.uo_out[7].value == 0, "hsync should be low during visible area"

    # Advance into the horizontal sync window (after front porch)
    await ClockCycles(dut.clk, 640 + 16 + 2)
    assert dut.uo_out[7].value == 1, "hsync should be high during horizontal sync"

    # After the sync period, hsync should return low
    await ClockCycles(dut.clk, 96)
    assert dut.uo_out[7].value == 0, "hsync should be low after horizontal sync"
