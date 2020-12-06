//-------------------------------------------------------------------------
//      VGA controller                                                   --
//      Kyle Kloepper                                                    --
//      4-05-2005                                                        --
//                                                                       --
//      Modified by Stephen Kempf 04-08-2005                             --
//                                10-05-2006                             --
//                                03-12-2007                             --
//      Translated by Joe Meng    07-07-2013                             --
//      Fall 2014 Distribution                                           --
//                                                                       --
//      Used standard 640x480 vga found at epanorama                     --
//                                                                       --
//      reference: http://www.xilinx.com/bvdocs/userguides/ug130.pdf     --
//                 http://www.epanorama.net/documents/pc/vga_timing.html --
//                                                                       --
//      note: The standard is changed slightly because of 25 mhz instead --
//            of 25.175 mhz pixel clock. Refresh rate drops slightly.    --
//                                                                       --
//      For use with ECE 385 Lab 7 and Final Project                     --
//      ECE Department @ UIUC                                            --
//-------------------------------------------------------------------------


module  vga_controller ( input        Clk,       // 50 MHz clock
                                      Reset,     // reset signal
                         output logic hs,        // Horizontal sync pulse.  Active low
								      vs,        // Vertical sync pulse.  Active low
									  blank,     // Blanking interval indicator.  Active low.
												  
								 output [9:0] DrawX,     // horizontal coordinate
								              DrawY );   // vertical coordinate
    
    // 800 horizontal pixels indexed 0 to 799
    // 525 vertical pixels indexed 0 to 524
        parameter [9:0] hpixels = 10'd799;
        parameter [9:0] vlines = 10'd524;
//    parameter [9:0] hpixels = 8'b10011111; // 160 height
//    parameter [9:0] vlines = 8'b10001111; // 144
	 
	 // horizontal pixel and vertical line counters
    logic [9:0] hc, vc;
    
	 // signal indicates if ok to display color for a pixel
	 logic display;
	 
    
   
	//Runs the horizontal counter  when it resets vertical counter is incremented
   always_ff @ (posedge Clk or posedge Reset )
	begin: counter_proc
		  if ( Reset ) 
			begin 
				 hc <= 10'h0;
				 vc <= 10'h0;
			end
				
		  else 
			 if ( hc == hpixels )  //If hc has reached the end of pixel count
			  begin 
					hc <= 10'h0;
					if ( vc == vlines )   //if vc has reached end of line count
						 vc <= 10'h0;
					else 
						 vc <= (vc + 10'h1);
			  end
			 else 
				  hc <= (hc + 10'h1);  //no statement about vc, implied vc <= vc;
	 end 
   
    assign DrawX = hc;
    assign DrawY = vc;
   
	 //horizontal sync pulse is 96 pixels long at pixels 656-752
    //(signal is registered to ensure clean output waveform)
    always_ff @ (posedge Reset or posedge Clk )
    begin : hsync_proc
        if ( Reset ) 
            hs <= 1'b0;
        else  
            if ((((hc + 1) >= 10'd656) & ((hc + 1) < 10'd752))) 
                hs <= 1'b0;
            else 
				    hs <= 1'b1;
    end
	 
    //vertical sync pulse is 2 lines(800 pixels) long at line 490-491
    //(signal is registered to ensure clean output waveform)
    always_ff @ (posedge Reset or posedge Clk )
    begin : vsync_proc
        if ( Reset ) 
           vs <= 1'b0;
        else 
            if ( ((vc + 1) == 9'd490) | ((vc + 1) == 9'd491) ) 
			       vs <= 1'b0;
            else 
			       vs <= 1'b1;
    end
       
    //only display pixels between horizontal 0-639 and vertical 0-479 (640x480)
    //(This signal is registered within the DAC chip, so we can leave it as pure combinational logic here)    
    always_comb
    begin 
        if ( (hc >= 10'd640) | (vc >= 10'd480) ) 
            display = 1'b0;
        else 
            display = 1'b1;
    end 
   
    assign blank = display;
    

endmodule
