;====================================================================
; DEFINITIONS
;====================================================================

.DEF VAR_OCR = R20
.DEF SECOND = R22
.DEF MINUTE = R23
.DEF TEN = R24
.DEF DELTA = R18

;====================================================================
; RESET and INTERRUPT VECTORS
;====================================================================

;.INCLUDE "M64DEF.INC"

.ORG 0X0000
   JMP MAIN

.ORG 0X0020
   JMP TIMER0_OVF_ISR

   
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
      CBI PORTB,4	;INITIAL STATE OF PORTB.4 WILL BE "0" VOLT FOR SAFTEY AT START !
      
; f_tcnt0 = (10.24M/1024) = 10 KHz   
; T_tcnt0 = 100 us

      LDI R16,56	;(256-56)*100us => EVERY 20ms OVF0. INTRUPTS!
      OUT TCNT0,R16
      LDI VAR_OCR,56	;AT THE FIRST MOMENT, OCR0 VALUE SHOULD BE 56 WHEN WE CLOSE SWICTH !
      OUT OCR0,VAR_OCR 
      LDI R16,0X4F	;FAST PWM {OC0 IS DISCONNECTED} & n=1024 (0100 1111)
      OUT TCCR0,R16
      LDI R16,0X01	;JUST OVF0. IS ENABLE! (0000 0001)
      OUT TIMSK,R16 
      
      CLR R21		;;
      CLR SECOND	;;      
      CLR MINUTE	;;    MEASURING TIME
      CLR TEN		;;
                   
      LDI DELTA,10	;("9.95" IS "5%" OF COUNTING RANGE{255-56=199})
      SEI

LOOP:
      SBIS PINA,4
      CALL CLOSE
      SBIC PINA,4
      CALL OPEN	
      JMP  LOOP
OPEN:
      LDI R16,0X4F
      OUT TCCR0,R16	;OC0 DISCONNECTED(NORMAL I/O PORT AT B.4)! (0100 1111)
      CBI PORTB,4	;(HOWEVER PORTB.4 HAD BEEN CLEARED BEFORE AT UPPER LINES!)
      
      LDI VAR_OCR,56
      OUT OCR0,VAR_OCR
      CLR R21		;;
      CLR SECOND	;;   
      CLR MINUTE      	;;   MEASURING TIME
      CLR TEN		;;
      RET

CLOSE:  
      LDI R16,0X6F
      OUT TCCR0,R16	;OC0 CONNECTED NON-INVERTING! (0110 1111)
      RET

;====================================================================
; INTERRUPT ISRs
;====================================================================

TIMER0_OVF_ISR:		;INTRUPTS EVERY 20ms
      LDI R17,56
      OUT TCNT0,R17
      
      CALL EV_20ms    
      RETI
;==============================
EV_20ms:
      INC R21
      CPI R21,50
      BRNE END_EV_20ms
      CLR R21
      CALL EV_1s
END_EV_20ms: RET
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
	 
	 IN VAR_OCR,OCR0
	 ADD VAR_OCR,DELTA
	 CPI VAR_OCR,0		;THIS OCCURS BECAUSE OF APPROXIMATION (9.75~10) AND WE HAVE TO REPAIR IT!
	 BRNE NEXT_1
	 LDI VAR_OCR,255	

NEXT_1:	 JMP END_OCR_CHANGER
	  
STAY_HIGH:	 
	 CPI MINUTE,10
	 BRLO END_OCR_CHANGER
	 BRNE DECREASE		;WHEN WE ARE IN THIS LINE OF CODE, MINUTE IS DEFINITELY "10 OR HIGHER" !
	 CPI SECOND,21
	 BRLO END_OCR_CHANGER
	 	 
DECREASE:
	 CPI MINUTE,13
	 BRLO PROG
	 BRNE STAY_LOW		;WHEN WE ARE IN THIS LINE OF CODE, MINUTE IS DEFINITELY "13 OR HIGHER" !
	 CPI SECOND,41
	 BRLO PROG

STAY_LOW: LDI MINUTE,15		;FREEZING TIME TO DO NOTHING AFTER 00:13:40 !

END_OCR_CHANGER: 
	 OUT OCR0,VAR_OCR	;VAR_OCR=R20 THAT IS ALWAYS CHANGING IN INTRUPT!
	 RET     
      
PROG:
	 INC TEN
	 CPI TEN,10
	 BRNE END_OCR_CHANGER
	 CLR TEN 
	 
	 IN VAR_OCR,OCR0
	 SUB VAR_OCR,DELTA
	 CPI VAR_OCR,245	;THIS OCCURS BECAUSE OF APPROXIMATION (9.75~10) AND WE HAVE TO REPAIR IT!
	 BRNE NEXT_2
	 LDI VAR_OCR,246	
	 
NEXT_2:	 JMP END_OCR_CHANGER
      
      
      
      
      
      
      
      
      
