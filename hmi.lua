mqttAction_limits = 11

json = require("json")

local obj
local err

-- MQTT Topics
local SUBSCRIBE_TOPIC = "testtopic/test/no1/7890"
local PUBLISH_TOPIC = "testtopic/test/no1/123456"
local RELAY_SUBSCRIBE_TOPIC = "home/relay/set"
local RELAY_PUBLISH_TOPIC = "home/relay/state"

local RELAY_SUBSCRIBE_TOPIC_5 = "home/relay/set_5"
local RELAY_SUBSCRIBE_TOPIC_6 = "home/relay/set_6"

local RELAY_PUBLISH_TOPIC_5 = "home/relay/state_5"
local RELAY_PUBLISH_TOPIC_6 = "home/relay/state_6"

-- Received message callback function
function mqtt_msg_callback(topic, msg)
    print("📥 Received MQTT Topic:", topic)
    print("📩 Message:", msg)

    if topic == SUBSCRIBE_TOPIC then
        local objMsg = json.decode(msg)
        if objMsg and objMsg.data then
            local water = objMsg.data.waterlevel
            local temp = objMsg.data.temperature
            local mi = objMsg.data.miflora 
            local mi2 = objMsg.data.miflora2 
            local mi3 = objMsg.data.miflora3 
            local mi4 = objMsg.data.miflora4 

            -- Save sensor readings to HMI
            we_bas_setword("@W_HDW30", mi * 10)
            we_bas_setword("@W_HDW50", mi2 * 10)
            we_bas_setword("@W_HDW60", mi3 * 10)
            we_bas_setword("@HDW70", mi4 * 10)                                   
            we_bas_setword("@W_HDW10", water)
            we_bas_setword("@W_HDW20", temp)
        end

    elseif topic == RELAY_SUBSCRIBE_TOPIC then
        if msg == "ON" then
            we_bas_setbit("@HDX1.0", 1)  -- Turn ON Relay (PLC)
        else
            we_bas_setbit("@HDX1.0", 0)  -- Turn OFF Relay (PLC)
        end
        -- ✅ Publish status update to HA
        send_relay_status()
        
        
    elseif topic == RELAY_SUBSCRIBE_TOPIC_5 then
    if msg == "ON" then
        we_bas_setbit("@HDX2.0", 1)  -- Turn ON Relay 2
    else
        we_bas_setbit("@HDX2.0", 0)  -- Turn OFF Relay 2
    end
    send_relay_status()    
        
    elseif topic == RELAY_SUBSCRIBE_TOPIC_6 then
    if msg == "ON" then
        we_bas_setbit("@HDX3.0", 1)  -- Turn ON Relay 3
    else
        we_bas_setbit("@HDX3.0", 0)  -- Turn OFF Relay 3
    end
    send_relay_status()    
        
    end
end

-- ✅ Function to check HMI button and send MQTT update
function check_hmi_button()
    local hmi_button_state = we_bas_getbit("@HDX1.0")  -- Read HMI Button

    if hmi_button_state == 1 then
        print("🟢 HMI Button Pressed: Sending MQTT ON")
        obj:publish(RELAY_PUBLISH_TOPIC, "ON", 0, 1)  
    else
        print("🔴 HMI Button Released: Sending MQTT OFF")
        obj:publish(RELAY_PUBLISH_TOPIC, "OFF", 0, 1)  
    end
end

-- Send relay status to MQTT
function send_relay_status()
    local relay_status = we_bas_getbit("@HDX1.0") == 1 and "ON" or "OFF"
    local relay_status_5 = we_bas_getbit("@HDX2.0") == 1 and "ON" or "OFF"
    local relay_status_6 = we_bas_getbit("@HDX3.0") == 1 and "ON" or "OFF"    
    
    print("📡 Publishing Relay Status:", relay_status)
    obj:publish(RELAY_PUBLISH_TOPIC, relay_status, 0, 1)  
    obj:publish(RELAY_PUBLISH_TOPIC_5, relay_status_5, 0, 1)
    obj:publish(RELAY_PUBLISH_TOPIC_6, relay_status_6, 0, 1)


end

-- Initialize MQTT
function mqtt_init()
    print("🚀 Initializing MQTT...")
    obj, err = mqtt.create(URL, CLIENT_ID)
    if obj then
        obj:on("message", mqtt_msg_callback)
        print("✅ MQTT initialized successfully")
    else
        print("❌ MQTT initialization failed:", err)
    end
end

-- Connect to MQTT
function mqtt_connect()
    local stat, err = obj:connect(config)
    if stat == nil then
        print("❌ MQTT connection failed:", err)
        return
    else
        print("✅ MQTT connected")
        obj:subscribe(SUBSCRIBE_TOPIC, 0)
        obj:subscribe(RELAY_SUBSCRIBE_TOPIC, 0)  
        obj:subscribe(RELAY_SUBSCRIBE_TOPIC_5, 0)  
        obj:subscribe(RELAY_SUBSCRIBE_TOPIC_6, 0)  
        
        
        
        
      
          
        
        
    end
end

-- Send sensor data
function send_data()
    local pub_data = {
        timestamp = os.time(),
        messageId = 2,
        event = "test_data",
        mfrs = "HMI",
        data = {
            id = uuid(),
            waterlevel = we_bas_getword("@W_HDW10"),
            temperature = we_bas_getword("@W_HDW20")
        }
    }
    print("📤 Publishing Sensor Data:", json.encode(pub_data))
    return obj:publish(PUBLISH_TOPIC, json.encode(pub_data), 0, 0)
end

-- MQTT loop execution
function mqtt_loop()
    if obj then
        if obj:isconnected() then
            send_data()
            send_relay_status()
            check_hmi_button()  -- ✅ Check HMI button every loop
        else
            mqtt_connect()
        end
    else
        mqtt_init()
    end
end
