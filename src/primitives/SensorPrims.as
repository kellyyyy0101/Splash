package primitives {
    import flash.utils.Dictionary;
	import blocks.*;
	import interpreter.*;
    import flash.net.*;
    import flash.events.NetStatusEvent;
public class SensorPrims {

    private var app:Scratch;
    private var interp:Interpreter;

    public var nc:NetConnection;
    public var ns:NetStream;
    public var groupSpec:GroupSpecifier;

    public var messages:Array = [{name:"", state:""},];

    public var lc:LocalConnection = new LocalConnection();
    public function SensorPrims(app:Scratch, interp:Interpreter) {
        this.app = app;
        this.interp = interp;

        
        lc.client = this;


        //  Initialize the Network Connection
        try {
            lc.connect("_connection");
        } catch (e:ArgumentError) {
            trace("Can't connect. The name is already used.");
        }

    }

    public function receiveMsg(msg:String, value:String):void
    {
        messages.push({name:msg, value:value});
        
    }
    //no longer used(if you want multi computer interaction, consider using a extension)
    /*public function onNetStatus(event:NetStatusEvent):void
    {
        switch(event.info.code){
             case "NetConnection.Connect.Success":
                setupMulticastGroup();
                break;
            
            case "NetGroup.Connect.Success":
            // Group connected, now set up the stream
                setupStream();
                break;
            
            case "NetStream.Connect.Success":
                break;
        }
    }

    public function setupMulticastGroup():void {
    
        groupSpec = new GroupSpecifier("myLocalGroup");
        
        // Enable local network P2P features
        groupSpec.multicastEnabled = true;
        groupSpec.ipMulticastMemberUpdatesEnabled = true;
        
        // Add the standard local multicast IP range (224.0.0.0 to 239.255.255.255)
        // 225.225.225.225:12345 is a safe default for LAN testing
        groupSpec.addIPMulticastAddress("225.225.225.225:12345");
    }

    public function setupStream():void {
        // Create the NetStream using the connection and the group configuration
        ns = new NetStream(nc, groupSpec.groupspecWithAuthorizations());
        ns.addEventListener(NetStatusEvent.NET_STATUS, onNetStatus);
        
        // Define an object to hold incoming function calls
        var clientObject:Object = new Object();
        
        // This is the function the other PC will trigger remotely
        clientObject.receiveMessage = function(msg:String):void {
            messages.push({name:msg, value:true});
            waitAndPass();
            for (var i:int = 0; i < messages.length; i++) {
                if(messages[i].name == msg){
                    messages[i].value = false
                }
            }
        };
        
        ns.client = clientObject;
        
        // Both publish and play on the same group stream name
        ns.play("localStreamName");
        ns.publish("localStreamName");
    }

    public function waitAndPass():void{

    }

    public function sendMessage(msg:String):void {
        if (ns) {
            ns.send("receiveMessage", msg);
        } else {
            //nothin'
        }
    }*/

    public function addPrimsTo(primTable:Dictionary):void {
		primTable["sendMsg"] = primSend;
        primTable["getMsg"] = primGetMsg;
        primTable["msgSent"] = primBoolMsg;
    }
    
    private function primSend(b:Block):void
    {
             
        lc.send("_connection", "receiveMsg", interp.arg(b, 0), interp.arg(b, 1));
        
    }

    private function primGetMsg(b:Block):*
    {
        for (var i:int = 0; i < messages.length; i++) {
                if(messages[i].name == interp.arg(b, 0)){
                    return(messages[i].value);
                }
            }
        return("")
    }

    private function primBoolMsg(b:Block):*{
        for (var i:int = 0; i < messages.length; i++) {
                if(messages[i].name == interp.arg(b, 0)){
                    return(true)
                }
            }
        return(false)
    }
}}