# ⚙️ AVR Assembly PWM Controller
![Language](https://img.shields.io/badge/Language-AVR%20Assembly-d29034?style=for-the-badge)
![Simulation](https://img.shields.io/badge/Simulation-Proteus-1B5082?style=for-the-badge)

This is a real-time control project written in **AVR Assembly** for the **ATmega64** microcontroller. The program generates a Pulse Width Modulation (PWM) signal that follows a precise, time-based sequence triggered by an external switch. The entire system is designed and verified using **Proteus** simulation software.

This project was submitted for the Digital Systems 2 course.

## 📋 Project Requirements
The operational logic of the PWM output is based on the state of a switch connected to the microcontroller:

* **1. Ramp-Up**: When the switch is **closed**, the effective (RMS) value of the output increases by **5% every second** until it reaches its maximum level.
* **2. Hold**: Once at maximum, the output remains constant for **10 minutes**.
* **3. Ramp-Down**: After the hold period, the output decreases by **5% every 10 seconds** until it returns to zero.
* **4. Interrupt**: If the switch is **opened** at any point, the output must immediately drop to zero.

## 💡 Implementation Details
The core of the project involves precise timekeeping and accurate calculation of the PWM duty cycle, which is controlled by the `OCR0` register (an 8-bit value from 0 to 255).

#### The Challenge: Avoiding Cumulative Error
A key challenge is to accurately increment or decrement the duty cycle by 5% of the maximum value (which is $0.05 \times 255 = 12.75$).
* A naive **incremental approach**, such as adding a rounded integer like `13` to the `OCR0` register each second, would lead to significant **cumulative rounding errors**. Over the 20-second ramp-up period, this error would cause the final value to miss the target of 255.
* To solve this, this project implements a more robust **proportional calculation method**.

#### The Proportional Method
Instead of incrementing, the target `OCR0` value is recalculated at each time step based on the elapsed time.
* The code uses a pre-calculated base number `NUM = 51`. This value is chosen because it is the first integer multiple of 12.75 (specifically, $12.75 \times 4 = 51$).
* During the ramp-up phase, the duty cycle is calculated with the formula: `OCR = (NUM * elapsed_seconds) / 4`.
* The division by 4 is implemented efficiently using two logical right shifts (`LSR`) on the 16-bit multiplication result.
* This method ensures that the calculation for each step is independent, preventing rounding errors from accumulating and guaranteeing accuracy throughout the entire sequence.

## 🛠️ Code and Hardware Structure
* **Microcontroller**: **ATmega64**.
* **Clock Speed**: **10.24 MHz**.
* **Timekeeping**: **Timer2** is configured in Normal mode with a prescaler of 1024. It overflows and triggers an Interrupt Service Routine (`TIMER2_OVF_ISR`) precisely every **25 ms**. This ISR acts as the system's heartbeat, managing counters for seconds and minutes.
* **PWM Generation**: **Timer0** is configured in **Fast PWM** mode (non-inverting) to generate the output signal on the `OC0` (PORTB.4) pin. The duty cycle is dynamically updated by writing the calculated values to the `OCR0` register.
* **Input**: The controlling switch is connected to `PINA.4`, which the `MAIN` loop continuously polls to call the appropriate subroutines (`OPEN` or `CLOSE`).
* **Logic**: The core logic for increasing, holding, and decreasing the PWM value resides in the `OCR_CHANGER` subroutine, which is called by the timekeeping ISR.
