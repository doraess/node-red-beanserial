###
scanBLE.js
Scans for a specific Bluetooth 4 (BLE) Device (by Name and UUID)
Returns the Name the of Device when found and stops scanning
Requires Noble: https://github.com/sandeepmistry/noble
Copyright 2013 Charalampos Doukas - @BuildingIoT

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
###

#might need to modify accordingly



# The main node definition - most things happen in here
Bean = (n) ->
  
  # Create a RED node
  RED.nodes.createNode this, n
  msg = {}
  ble_name = undefined
  node = this
  
  #get name and uuid from user
  @ble_name = n.ble_name
  @ble_uuid = n.ble_uuid
  @active = false
  node.status
    fill: "grey"
    shape: "dot"
    text: "no data"

  @on "input", (msg) ->
    @active = true
    noble.startScanning()

  @on "close", ->
    try
      noble.stopScanning()
    catch err
      console.log err

  noble.on "scanStart", (msg) ->
    msg = {}
    msg.topic = node.topic
    msg.payload = "Scanning initiated..." #debugging
    return

  #node.send(msg);
  noble.on "discover", (peripheral) ->
    msg = {}
    msg.topic = node.topic
    msg.payload = "not found"
    
    #check for the device name and the UUID (first one from the UUID list)
    if peripheral.uuid is node.ble_uuid and node.active
      node.status
        fill: "yellow"
        shape: "ring"
        text: "found"

      msg.payload = peripheral.advertisement
      noble.stopScanning()
      
      #node.send("Found");
      #console.log('Found...');
      peripheral.connect (error) ->
        if error
          node.status
            fill: "red"
            shape: "dot"
            text: "error"
          console.log "Connection error:" + error
        else
          #console.log('Connected...');
          node.status
            fill: "green"
            shape: "dot"
            text: "connected"

          peripheral.discoverAllServicesAndCharacteristics (error, services, characteristics) ->
            node.status
              fill: "blue"
              shape: "dot"
              text: "quering"
            #console.log('Quering...');
            if error
              node.status
                fill: "red"
                shape: "dot"
                text: "error"
              console.log "Query error:" + error
            else
              #console.log "Services: " + services + "\nCharacteristics: " + [characteristic] for characteristics in characteristics when characteristic.uuid is "a495ff21c5b14b44b5121370f02d74de" 
              #console.log "Characteristics: " + [characteristic for characteristic in characteristics when characteristic.uuid is "a495ff21c5b14b44b5121370f02d74de"]
              #console.log "Battery: #{battery} \nScratch[#{scratch.length}]: #{scratch}" 
              async.series [ 
                (callback) ->
                  battery = (item for item in characteristics when item.uuid is "2a19")
                  if battery.length
                    battery[0].read (error, data) ->
                      if error
                        node.status
                          fill: "red"
                          shape: "dot"
                          text: " error"
                        console.log "Read error:" + error
                      else
                        console.log "Batería: " + data
                        msg.payload.battery = data[0]
                        msg.payload.voltage = (data[0]*1.75*0.01 + 2).toFixed(2)
                        callback() 
                  else 
                    msg.payload.battery = "-"
                    callback()  
                (callback) ->
                  async.each characteristics, ((characteristic, callback) ->
                    characteristic.discoverDescriptors (error, descriptors) ->
                      async.detect descriptors, ((descriptor, callback) ->
                        callback descriptor.uuid is "2901"
                      ), (userDescriptionDescriptor) ->
                        if userDescriptionDescriptor
                          userDescriptionDescriptor.readValue (error, data) ->
                            if /Scratch/.test data.toString()
                              node.status
                                fill: "blue"
                                shape: "dot"
                                text: " quering #{data.toString()}"
                              characteristic.read (error, value) ->
                                msg.payload[data.toString()] = value
                                callback()
                            else
                              callback()
                        else
                          callback()
                  ), (error) ->
                    callback()
              ], (err, results) ->
                msg.payload.uuid = peripheral.uuid
                msg.payload.rssi = peripheral.rssi
                peripheral.disconnect()
                node.active = false
                node.status
                  fill: "green"
                  shape: "ring"
                  text: msg.payload.battery + "%, " + msg.payload.voltage + "v, " + peripheral.rssi + " dB"
                node.send msg

RED = require(process.env.NODE_RED_HOME + "/red/red")
#import noble
noble = require("noble")
async = require("async")

# Register the node by name. This must be called before overriding any of the
# Node functions.
RED.nodes.registerType "Bean", Bean
