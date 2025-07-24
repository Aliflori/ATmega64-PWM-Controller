;====================================================================
; DEFINITIONS
;====================================================================

.DEF VAR_OCR = R20
.DEF SECOND = R22
.DEF MINUTE = R23
.DEF TEMP = R24
.DEF TEN = R25
.DEF NUM = R18

;====================================================================
; RESET and INTERRUPT VECTORS
;====================================================================

.INCLUDE "M64DEF.INC"

.ORG 0X0000
   JMP MAIN

.ORG 0X0014
   JMP TIMER2_OVF_ISR
   
;====================================================================
; MAIN CODE SEGMENT
;====================================================================

.ORG 0X0050
MAIN:
      LDI R16,HIGH(RAMEND)
      OUT SPH,R16
      LDI R16,LOW(RAMEND)
      OUT SPL,R16

      CBI DDRA,4	;MAKE PORTA.4 AS AN INPUT(<==:0)
      SBI DDRB,4        ;MAKE PORTB.4 AS AN OUTPUT(==>:1)
      CBI PORTB,4	;INITIAL STATE OF PORTB.4 WILL BE "0" VOLT FOR SAFTEY OF  STARTING !
      
; f_tcnt0 = (10.24M/1) = 10.024 MHz   
;T_tcnt0 =~ 25 us (I CHOSED PRESCALER=1 BECAUSE UPDATING OCR0 FROM "OCR0 BUFFER" VERY VERY QUICKLY !)

      LDI R16,0		
      OUT TCNT0,R16
      CLR VAR_OCR	;AT FIRST MOMENT, OCR0 VALUE SHOULD BE 0 WHEN WE CLOSE SWICTH!
      OUT OCR0,VAR_OCR		
      LDI R16,0X49	;FAST PWM {OC0 DISCONNECTED} & n=1 (0100 1001)
      OUT TCCR0,R16
      LDI R16,0X40	;JUST OVF2. IS ENABLE! (0100 0000)
      OUT TIMSK,R16
      
; f_tcnt2 = (10.24M/1024) = 10 KHz  ,  T_tcnt2 = 100 us

      LDI R16,6		;(256-6)*100us => EVERY 25ms OVF2. INTRUPTS!
      OUT TCNT2,R16
      LDI R16,0X07	;NORMAL MODE & n=1024 (0000 0111)
      OUT TCCR2,R16
      
      CLR R21		;;
      CLR SECOND	;;      MEASURING TIME
      CLR MINUTE	;;
      CLR TEMP
      CLR TEN

      
;THE FIRST INTEGER MULTIPLE OF 12.75 IS NUMBER 51. (51 == 12.75 * 4)
;                  (12.75 IS 5% OF 255)      
      LDI NUM,51	
      SEI

LOOP:
      SBIS PINA,4
      CALL CLOSE
      SBIC PINA,4
      CALL OPEN	
      JMP  LOOP
OPEN:
      LDI R16,0X49
      OUT TCCR0,R16	;OC0 DISCONNECTED(NORMAL I/O PORT)! (0100 1001)
      CBI PORTB,4	;HOWEVER PORTB.4 HAS BEEN CLEARED (AT INITIALIZING SECTION)!
      
      CLR VAR_OCR
      OUT OCR0,VAR_OCR
      CLR R21		;;
      CLR SECOND	;;   MEASURING TIME
      CLR MINUTE      	;;
      CLR TEMP
      CLR TEN
      RET

CLOSE:  
      LDI R16,0X69
      OUT TCCR0,R16	;OC0 CONNECTED NON-INVERTING! (0110 1001)
      OUT OCR0,VAR_OCR
      RET

;====================================================================
; INTERRUPT ISRs
;====================================================================

TIMER2_OVF_ISR:		;INTRUPTS EVERY 25ms
      LDI R17,6
      OUT TCNT2,R17
      
      CALL EV_25ms    
      RETI
;==============================
EV_25ms:
      INC R21
      CPI R21,40
      BRNE END_EV_25ms
      CLR R21
      CALL EV_1s
END_EV_25ms: RET
;============================== 
EV_1s:
      INC SECOND
      CPI SECOND,60
      BRNE ENDING
      CLR SECOND
      CALL EV_1m 
ENDING: CALL OCR_CHANGER        
      RET 
;============================== 
EV_1m:
      INC MINUTE
      CPI MINUTE,60
      BRNE END_EV_1m
      CLR MINUTE   
END_EV_1m: RET 
;====================================================================
; SUB PROGRAMS:
;====================================================================   
   
OCR_CHANGER:
	 
INCREASE:
	 CPI MINUTE,0
	 BRNE STAY_HIGH
	 CPI SECOND,21
	 BRSH STAY_HIGH
	 
	 MUL NUM,SECOND
	 LSR R1
	 ROR R0		
	 LSR R1
	 ROR R0		;DEVIDED TO 4
	 
	 MOV VAR_OCR,R0
	 JMP END_OCR_CHANGER
	  
STAY_HIGH:	 
	 CPI MINUTE,10
	 BRLO END_OCR_CHANGER
	 BRNE DECREASE	;WHEN WE ARE IN THIS LINE OF CODE, MINUTE IS DEFINITELY "10 OR HIGHER" !
	 CPI SECOND,21
	 BRLO END_OCR_CHANGER
	 	 
DECREASE:
	 CPI MINUTE,13
	 BRLO PROG
	 BRNE STAY_LOW	;WHEN WE ARE IN THIS LINE OF CODE, MINUTE IS DEFINITELY "13 OR HIGHER" !
	 CPI SECOND,41
	 BRLO PROG

STAY_LOW: LDI MINUTE,15		;FREEZING TIME TO DO NOTHING AFTER 00:13:40 !
END_OCR_CHANGER: RET     
      
PROG:
	 INC TEMP
	 CPI TEMP,10
	 BRNE END_OCR_CHANGER
	 CLR TEMP
	 INC TEN	;EVERY 10s 
	 
	 MUL NUM,TEN
	 LSR R1
	 ROR R0		
	 LSR R1
	 ROR R0		;DEVIDED TO 4
	 
	 COM R0
	 MOV VAR_OCR,R0
	 JMP END_OCR_CHANGER
      
      
      
      
      
      
      
      
      
