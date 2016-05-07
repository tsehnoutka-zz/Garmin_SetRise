//!
//! Copyright 2015 by Garmin Ltd. or its subsidiaries.
//! Subject to Garmin SDK License Agreement and Wearables
//! Application Developer Agreement.
//!
using Toybox.Graphics;
using Toybox.Communications as Comm;
using Toybox.WatchUi as Ui;
using Toybox.System as Sys;
using Toybox.Lang as Lang;

//  I editted this on the GitHub website


//*****************************************************************************
//***	This class does the work 
//*****************************************************************************
class BaseInputDelegate extends Ui.BehaviorDelegate {
    var notify;   //  used to call int o the View
    var posnInfo = null;  //  used to get teh lat long
	var lat = 0;
	var lng = 0;
	var alt =-10;
    var sRise;  // sunrise
    var sSet;   // sunset
    var mTime = Sys.getClockTime();
    var DST=mTime.dst;
    var offset=mTime.timeZoneOffset;
     

  
 
	//***************************************************************
	//***   When the Menu button is pressed, Make a JSON call to get 
	//***   the Sunrise and Sunset data
	//***************************************************************
    function onMenu() {
        notify.invoke("Executing\nRequest");
        
        if ( null == posnInfo){
        	notify.invoke( "No Location Found" );
        }
		else{       
	        lat = posnInfo.position.toDegrees()[0].toString();
	        lng = posnInfo.position.toDegrees()[1].toString();
	        alt = posnInfo.altitude;
	        Sys.println( "location: " + lat + "," + lng );
   		    Sys.println("DST: " + DST); 
        	Sys.println("off Set: " + offset);
	         //"http://api.sunrise-sunset.org/json?lat=36.7201600&lng=-4.4203400",
	        Comm.makeJsonRequest(
	            "http://api.sunrise-sunset.org/json",
	            {
	               "lat" => lat,
	               "lng" => lng
	            },
	            {
	                "Content-Type" => Comm.REQUEST_CONTENT_TYPE_URL_ENCODED
	            },
	            method(:onReceive)
	        );
        }  //  end if-else
        return true;
    }  //  End onMenu()

	//***************************************************************
	//***   Called when this class is intialized 
	//***************************************************************
    function initialize(handler) {
        Ui.BehaviorDelegate.initialize();
        notify = handler;
    }

	//***************************************************************
	//***   This function receives the response from the web page
	//***   For this page the information is returned in a dictionary
	//***   named "results"
	//***************************************************************
    function onReceive(responseCode, data) {
    	Sys.println("in On Receive " + responseCode);
        
        if( responseCode == 200 ) {
        	sRise = data.get("results").get("sunrise");
        	sSet  = data.get("results").get("sunset");
        	Sys.println("Sunrise: " + sRise + "; Sunset: " + sSet);
      		sRise = applyOffset(sRise, DST, offset);
       		sSet  = applyOffset(sSet,  DST, offset);
       		
       		//  negative LAt is south;  negative Long is East
           	var strOutput = Lang.format("lat: $1$\nlng: $2$\nalt: $3$ ft\nsunrise: $4$\nsunset: $5$", [lat,lng,alt.format("%d"),sRise.toString(),sSet.toString()]);
           	notify.invoke(strOutput);
           	//notify.invoke(  "\nlat: " + lat + "\nlng: " + lng + "\nAltitude: "+ alt+ "\nsunrise: " + sRise.toString() + "\nsunset: " + sSet.toString() );
        }
        else {
        	if (-104 == responseCode){
            	notify.invoke( "Connection Unavailable" );
        	}
        	if (-300 == responseCode){
            	notify.invoke( "Request Timed Out" );
        	}
        	else{
            	notify.invoke( "Failed to load\nError: " + responseCode.toString() );
            }
        }
        Sys.println("END On Receive");
    }  //  end of onRecieve()
	
    
	//***************************************************************
	//***   This function is called from the application
	//***   Its purpose is to get the data from the app class.
	//***************************************************************
     function setPosition(info) {
        posnInfo = info;
        
    }
    
    
    function applyOffset(fTime, fDST, fOffset)
    {
    	//fOffset = 19800;  //  test India
    	Sys.println("\nStart of Apply Offset");
    	var retVal="";
    	var switchAP=false;
    	var dTime = splitTime(fTime);
    	
    	//  Convert time to seconds
		var HoursInSec=dTime["hour"].toNumber() *3600; 
		var MinsInSec=dTime["min"].toNumber() * 60; 
		var SecsInSec=dTime["sec"].toNumber(); 
		var nTimeInSec = HoursInSec + MinsInSec + SecsInSec;

		var totalOffset = fOffset + 3600*DST;  //Add DST to off set
		var CorrectedTime = nTimeInSec + totalOffset;  // Add offset to time
		
		if ( nTimeInSec < totalOffset.abs()) //  if after the adjustment , the time is negative
		{
			nTimeInSec = nTimeInSec + 12 * 3600;  //  add 12 hours to the time
			CorrectedTime = nTimeInSec + totalOffset;  //  correct for offset
			switchAP=true;
		}

		//  Convert time from Sec to time
		var newHours = CorrectedTime / 3600;
		var newMin = (CorrectedTime - newHours*3600) / 60;
		var newSec = CorrectedTime - newHours*3600 - newMin*60;
		
		if (12 < newHours){ // after teh offset, teh time is greater than 12
			newHours = newHours - 12;
			switchAP = true;
		}
		Sys.println("New Time: " + newHours + "; " + newMin + "; " + newSec);

		//  when do I need to switch AM / PM??
		//  when after the offset, the time is negative or greater than 12  
		//  if time is 12, and the offset is negative
		//  if the time is 11 and the offset is positve  
		//  switch AM and PM
		Sys.println("Switch ? " + switchAP + " hour: " + dTime["hour"] + "  Total Offset: " + totalOffset);
		if(switchAP || (12 == dTime["hour"].toNumber() && 0 > totalOffset) || (11 == dTime["hour"].toNumber() && 0 < totalOffset) ) 
		{
			Sys.println("Switch");
			dTime["AP"] = switchDayandNight(dTime["AP"]);
		}

		//var devSet = Sys.DeviceSettings;
		var settings=Sys.getDeviceSettings();
		if(settings.is24Hour){
			var milHours = newHours.toNumber();
			if("P" == dTime["AP"]){
				milHours+=12;   //  add 12 to the afternoon
			}
			retVal = Lang.format("$1$:$2$:$3$ $4$", [milHours.format("%2d"),newMin.format("%02d"),newSec.format("%02d"), ""]);		
		}
		else{
			retVal = Lang.format("$1$:$2$:$3$ $4$M", [newHours.format("%2d"),newMin.format("%02d"),newSec.format("%02d"), dTime["AP"]]);
		}
		Sys.println("End of calculate Offset: " + retVal + "\n");
		
		//  retunr new string
		return retVal;
	}
    
    function switchDayandNight(f_AP)
    {
    	Sys.println("in Switch AMPM: " + f_AP);
		if (f_AP.equals("P")){
			f_AP="A";
		}
		else{
			f_AP="P";
		}
    	Sys.println("END Switch AMPM: " + f_AP);
		return f_AP;
    }
    
    function splitTime(fTime)
    {
    	var dTime ={ "hour"=>0, "min"=>0, "sec"=>0, "AP"=> "X"};
    	var strLeng = fTime.length;
    	var index = fTime.find(":");  //  poiunt to the first :
		dTime["hour"] = fTime.substring(0,index);
    	
    	var tempString = fTime.substring(index+1,8);
    	var index2 = tempString.find(":");  // point to the second :
    	dTime["min"] = tempString.substring(0,index2);
    	    
    	dTime["sec"] = tempString.substring(index2+1, index2+3);
    	
    	index = fTime.find("M");
    	dTime["AP"] = fTime.substring(index-1,index);
    	
    	Sys.println("Split Time - dTime:" + dTime);
    	return dTime;
    }  //  end Split TIme
    
}


//*****************************************************************************
//***	This class displays on the screen 
//*****************************************************************************
class Garmin_SetRiseView extends Ui.View {
    hidden var mMessage = "Press menu button";

    function initialize() {
        Ui.View.initialize();
    }

    //! Load your resources here
    function onLayout(dc) {
        mMessage = "Press menu button";  //  the initial view on the screen
    }

    //! Restore the state of the app and prepare the view to be shown
    function onShow() {
    }

    //! Update the view  (display the message on the screen)
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_WHITE);
        dc.clear();
        dc.drawText(10, dc.getHeight()/2, Graphics.FONT_MEDIUM, mMessage, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    //! Called when this View is removed from the screen. Save the
    //! state of your app here.
    function onHide() {
    }

	//***************************************************************
	//***   This function re parses the data received from 
	//***   the web site.
	//***************************************************************
    function onReceive(args) 
    {
        if (args instanceof Lang.String){
            mMessage = args;
        }
        else{
        	Sys.println("Message wasn't a string");  // print error message
        }
        
        Ui.requestUpdate();  // Update the display
    }  //  end onReceive function

}




