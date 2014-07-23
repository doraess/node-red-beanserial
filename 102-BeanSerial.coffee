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
  @ble_name = undefined
  node = this
  
  #get name and uuid from user
  @command = n.command
  @uuid = n.uuid
  @active = false
  node.status
    fill: "grey"
    shape: "dot"
    text: "no data"

  @on "input", (msg) ->
    @active = true
    noble.startScanning()
    @message = msg.topic
    @value = msg.payload

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

    peripheral.on "connect", () ->
      if node.active
        node.status
          fill: "green"
          shape: "dot"
          text: "connected"
        console.log "Connected"

    peripheral.on "disconnect", () ->
      if node.active
        node.status
          fill: "green"
          shape: "ring"
          text: "disconnected"
        console.log "Disconnected"
      node.active = false
    
    #check for the device name and the UUID (first one from the UUID list)
    if peripheral.uuid is node.uuid and node.active
      node.status
        fill: "yellow"
        shape: "ring"
        text: "found"

      msg.payload = peripheral.advertisement
      noble.stopScanning()

      peripheral.connect (error) ->
        if error
          node.status
            fill: "red"
            shape: "dot"
            text: "error"
          console.log "Connection error:" + error
        else
          peripheral.discoverServices [], (error, services) ->
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
              
              services[4].discoverCharacteristics [], (err, characteristics) ->
                characteristic = characteristics[0]

                characteristic.on "read", (data) ->
                  console.log data
                  decodeMessage data
                  peripheral.disconnect()
              
                characteristic.notify true, (err) ->
                  throw err if err
                  console.log "Successfully subscribed to Bean serial notifications."
                  sendCommand characteristic, commands[node.command], new Buffer([]), () ->
                    node.send msg

                  #node.status
                  #  fill: "green"
                  #  shape: "dot"
                  #  text: "disconnected"
                  #peripheral.disconnect()
                  

sendCommand = (characteristic, cmdBuffer, payloadBuffer, callback) ->
  
  #size buffer contains size of(cmdBuffer, and payloadBuffer) and a reserved byte set to 0
  sizeBuffer = new Buffer(2)
  sizeBuffer.writeUInt8 cmdBuffer.length + payloadBuffer.length, 0
  sizeBuffer.writeUInt8 0, 1
  
  #GST contains sizeBuffer, cmdBuffer, and payloadBuffer
  gstBuffer = Buffer.concat([
    sizeBuffer
    cmdBuffer
    payloadBuffer
  ])
  crcString = crc.crc16ccitt(gstBuffer)
  crc16Buffer = new Buffer(crcString, "hex")
  
  #GATT contains sequence header, gstBuffer and crc166
  gattBuffer = new Buffer(1 + gstBuffer.length + crc16Buffer.length)
  header = (((@count++ * 0x20) | 0x80) & 0xff)
  gattBuffer[0] = header
  gstBuffer.copy gattBuffer, 1, 0 #copy gstBuffer into gatt shifted right 1
  
  #swap 2 crc bytes and add to end of gatt
  gattBuffer[gattBuffer.length - 2] = crc16Buffer[1]
  gattBuffer[gattBuffer.length - 1] = crc16Buffer[0]
  characteristic.write gattBuffer, false, (error) ->
    if error
      console.log error
    else
      console.log "Done"
      callback()

decodeMessage = (message) ->
  seq = message[0]
  size = message[1]
  crcString = crc.crc16ccitt message[1..size + 3]

  crc16 = new Buffer crcString, 'hex'
  console.log crc16
  valid = (crc16[0] is message[message.length - 1] and crc16[1] is message[message.length - 2])

  type = new Buffer([message[3], message[4]])
  for key, value of commands
    #console.log "option(value='#{key}') #{key}"
    if value[0] is type[0] and value[1] is type[1]
      console.log "#{key}: length:#{parseInt size} crc:#{crc16[0]}#{crc16[1]}"
    


RED = require(process.env.NODE_RED_HOME + "/red/red")
#import noble
noble = require("noble")
async = require("async")
crc = require('crc')

# Register the node by name. This must be called before overriding any of the
# Node functions.
RED.nodes.registerType "Bean Serial", Bean

commands =
  MSG_ID_SERIAL_DATA: new Buffer([
    0x00
    0x00
  ])
  MSG_ID_BT_SET_ADV: new Buffer([
    0x05
    0x00
  ])
  MSG_ID_BT_SET_CONN: new Buffer([
    0x05
    0x02
  ])
  MSG_ID_BT_SET_LOCAL_NAME: new Buffer([
    0x05
    0x04
  ])
  MSG_ID_BT_SET_PIN: new Buffer([
    0x05
    0x06
  ])
  MSG_ID_BT_SET_TX_PWR: new Buffer([
    0x05
    0x08
  ])
  MSG_ID_BT_GET_CONFIG: new Buffer([
    0x05
    0x10
  ])
  MSG_ID_BT_ADV_ONOFF: new Buffer([
    0x05
    0x12
  ])
  MSG_ID_BT_SET_SCRATCH: new Buffer([
    0x05
    0x14
  ])
  MSG_ID_BT_GET_SCRATCH: new Buffer([
    0x05
    0x15
  ])
  MSG_ID_BT_RESTART: new Buffer([
    0x05
    0x20
  ])
  MSG_ID_BL_CMD: new Buffer([
    0x10
    0x00
  ])
  MSG_ID_BL_FW_BLOCK: new Buffer([
    0x10
    0x01
  ])
  MSG_ID_BL_STATUS: new Buffer([
    0x10
    0x02
  ])
  MSG_ID_CC_LED_WRITE: new Buffer([
    0x20
    0x00
  ])
  MSG_ID_CC_LED_WRITE_ALL: new Buffer([
    0x20
    0x01
  ])
  MSG_ID_CC_LED_READ_ALL: new Buffer([
    0x20
    0x02
  ])
  MSG_ID_CC_ACCEL_READ: new Buffer([
    0x20
    0x10
  ])
  MSG_ID_CC_ACCEL_READ_RSP: new Buffer([
    0x20
    0x90
  ])
  MSG_ID_AR_SET_POWER: new Buffer([
    0x30
    0x00
  ])
  MSG_ID_AR_GET_CONFIG: new Buffer([
    0x30
    0x06
  ])
  MSG_ID_DB_LOOPBACK: new Buffer([
    0xFE
    0x00
  ])
  MSG_ID_DB_COUNTER: new Buffer([
    0xFE
    0x01
  ])
  MSG_ID_CC_TEMP_READ : new Buffer([
    0x20
    0x11
  ])
  MSG_ID_CC_TEMP_READ_RSP : new Buffer([
    0x20
    0x91
  ])
  MSG_ID_CC_LED_READ_ALL_RSP : new Buffer([
    0x20
    0x82
  ])
