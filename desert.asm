                        //------------------------------------------------------------------------------
						// heartbeat 2021
                        // ==============
                        //
                        // started : 04/01/2021
                        //
                        // version : 0a
                        //
                        // code     : case
                        // help     : dano
                        // gfx      : 
                        // music    : 
                        // support  : dano, anonym
                        //------------------------------------------------------------------------------
						BasicUpstart2(start)
                        //------------------------------------------------------------------------------
                        // road map
                        // 
                        // 1. clear screen
                        // 2. fade in 'padua' logo, wait and fade out
                        // 3. display 'presents' (maybe do as sprites)
                        // 4. depack 'heartbeat' bitamp and draw on screen. do effect using timing tables
                        //    to swap in $d011 line by line from tom to bottom.
                        // 5. clear main bitmap in reverse of bringing it on
                        // 6. display main heartbeat screen (yet to be designed)
                        // 7. play music and let user pick from a list.
                        //------------------------------------------------------------------------------

                        //------------------------------------------------------------------------------
						// import music - default tune for the intro section only
                        //------------------------------------------------------------------------------
						.var music = LoadSid("Soldier_of_Fortune.sid")
						*=music.location "Music"
        				.fill music.size, music.getData(i)
                        //------------------------------------------------------------------------------

                        //------------------------------------------------------------------------------
						// import standard library definitions
                        //------------------------------------------------------------------------------
						#import "standardLibrary.asm" 
                        //------------------------------------------------------------------------------

                        //------------------------------------------------------------------------------
						// incude cruncher plugin
                        //------------------------------------------------------------------------------
                        // .plugin "e:\kickassember\kickass-cruncher-plugins-2.0.jar"
                        //------------------------------------------------------------------------------

						//------------------------------------------------------------------------------
						*=$4800 "heartbeat 2021 start"
start:		
				        ldx #$ff
				        txs
				        lda #$00
				        sta 650
				        lda #$80
				        sta 657

						lda border
						sta clearColor
						sta bordercolor
						lda screen
						sta screencolor

						lda #$00
						tay
						tax
						jsr music.init

						sei
						lda #$35
						sta $01
						lda #$1b
						sta screenmode
						lda #00
						sta raster
						lda #$81
						sta irqenable
						lda #21
						sta charset
						lda #200
						sta smoothpos
						lda #$7f
						sta $dc0d
						sta $dd0d
						lda #$01
						sta irqflag
						sta irqenable						
						ldx #<irq1
						ldy #>irq1
						stx $fffe
						sty $ffff
						cli

introwait:				jmp introwait

						jmp dologo
                        //------------------------------------------------------------------------------
nmi:					rti
                        //------------------------------------------------------------------------------
irq1:  					pha
						txa
						pha
						tya
						pha

						lda bordercolor
						sta border
						lda screencolor
						sta screen

						jsr music.play
clean:					jsr clearscreen
fade:					lda fade2black

						lda #$01
						sta $d019	
						pla
						tay
						pla
						tax
						pla
						rti
                        //------------------------------------------------------------------------------
clearscreen:			ldx clearXcounter
						lda #160
						sta $0400,x
						sta $0500,x
						sta $0600,x
						sta $0700,x
						lda clearColor
						sta $d800,x
						sta $d900,x
						sta $da00,x
						sta $db00,x
						inc clearXcounter
						beq clearscreen2
						rts
clearscreen2:			lda #$ad
						sta clean
						lda #$20
						sta fade
						rts
                        //------------------------------------------------------------------------------
fade2black:				lda fadedelay
	        			sec
	        			sbc #$04
	        			and #$07
	        			sta fadedelay
	        			bcc fade2black2
	        			rts

fade2black2:			ldx fadecolourcounter
						cpx #9
						beq fade2black3
						lda fadecolourtable,x
						sta bordercolor
						sta screencolor
						inc fadecolourcounter
						rts
fade2black3:			lda #$ad
						sta fade
						sta introwait
						rts
                        //------------------------------------------------------------------------------
screencolor:			.byte $00
bordercolor:			.byte $00
clearColor:				.byte $00			// grab border colour and store
clearXcounter:			.byte $00			// count columns
clearYcounter:			.byte $00			// count row
fadecolourtable:		.byte $01,$01,$0f,$0f,$0e,$0e,$06,$06,$00,$00
fadecolourcounter:		.byte $00			// fade colour number
fadedelay:				.byte $00			// controls the 1st fade speed
                        //------------------------------------------------------------------------------

                        //------------------------------------------------------------------------------
						.align $100

						.var logomatrix = $3000
                        //------------------------------------------------------------------------------
						// bring in the padua logo
                        //------------------------------------------------------------------------------
dologo:

						// draw logo matrix on screen

						ldx #$00

			!:			lda logomatrix,x
						sta $0400 + (40 * 10),x 				// define 1st line of logo on screen
						lda logomatrix + 40,x
						sta $0400 + (40 * 11),x 				// define 1st line of logo on screen
						lda logomatrix + 80,x
						sta $0400 + (40 * 12),x 				// define 1st line of logo on screen

						inx
						cpx #40
						bne !-


						sei
						lda #$7f
						sta $dc0d
						sta $dd0d
						lda #$81
						sta irqenable
						lda #$01
						sta irqflag
						sta irqenable						
						ldx #<logoirq
						ldy #>logoirq
						stx $fffe
						sty $ffff
						cli

dologo_wait:			jmp dologo_wait



                        //------------------------------------------------------------------------------
logoirq:				pha
						txa
						pha
						tya
						pha
						lda #BLACK
						sta border
						sta screen


						lda #$1b
						sta screenmode
						lda #$34
						sta raster
						lda #24
						sta charset
						lda #216
						sta smoothpos


						jsr music.play


						lda #$01
						sta $d019	
						pla
						tay
						pla
						tax
						pla
						rti
                        //------------------------------------------------------------------------------
