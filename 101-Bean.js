// Generated by CoffeeScript 1.7.1

/*
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
 */

(function() {
  var Bean, RED, async, noble;

  Bean = function(n) {
    var ble_name, msg, node;
    RED.nodes.createNode(this, n);
    msg = {};
    ble_name = void 0;
    node = this;
    this.ble_name = n.ble_name;
    this.ble_uuid = n.ble_uuid;
    this.active = false;
    node.status({
      fill: "grey",
      shape: "dot",
      text: "no data"
    });
    this.on("input", function(msg) {
      this.active = true;
      return noble.startScanning();
    });
    this.on("close", function() {
      var err;
      try {
        return noble.stopScanning();
      } catch (_error) {
        err = _error;
        return console.log(err);
      }
    });
    noble.on("scanStart", function(msg) {
      msg = {};
      msg.topic = node.topic;
      msg.payload = "Scanning initiated...";
    });
    return noble.on("discover", function(peripheral) {
      msg = {};
      msg.topic = node.topic;
      msg.payload = "not found";
      if (peripheral.uuid === node.ble_uuid && node.active) {
        node.status({
          fill: "yellow",
          shape: "ring",
          text: "found"
        });
        msg.payload = peripheral.advertisement;
        noble.stopScanning();
        return peripheral.connect(function(error) {
          if (error) {
            node.status({
              fill: "red",
              shape: "dot",
              text: "error"
            });
            return console.log("Connection error:" + error);
          } else {
            node.status({
              fill: "green",
              shape: "dot",
              text: "connected"
            });
            return peripheral.discoverAllServicesAndCharacteristics(function(error, services, characteristics) {
              node.status({
                fill: "blue",
                shape: "dot",
                text: "quering"
              });
              if (error) {
                node.status({
                  fill: "red",
                  shape: "dot",
                  text: "error"
                });
                return console.log("Query error:" + error);
              } else {
                return async.series([
                  function(callback) {
                    var battery, item;
                    battery = (function() {
                      var _i, _len, _results;
                      _results = [];
                      for (_i = 0, _len = characteristics.length; _i < _len; _i++) {
                        item = characteristics[_i];
                        if (item.uuid === "2a19") {
                          _results.push(item);
                        }
                      }
                      return _results;
                    })();
                    if (battery.length) {
                      return battery[0].read(function(error, data) {
                        if (error) {
                          node.status({
                            fill: "red",
                            shape: "dot",
                            text: " error"
                          });
                          return console.log("Read error:" + error);
                        } else {
                          console.log("Batería: " + data);
                          msg.payload.battery = data[0];
                          msg.payload.voltage = (data[0] * 1.75 * 0.01 + 2).toFixed(2);
                          return callback();
                        }
                      });
                    } else {
                      msg.payload.battery = "-";
                      return callback();
                    }
                  }, function(callback) {
                    return async.each(characteristics, (function(characteristic, callback) {
                      return characteristic.discoverDescriptors(function(error, descriptors) {
                        return async.detect(descriptors, (function(descriptor, callback) {
                          return callback(descriptor.uuid === "2901");
                        }), function(userDescriptionDescriptor) {
                          if (userDescriptionDescriptor) {
                            return userDescriptionDescriptor.readValue(function(error, data) {
                              if (/Scratch/.test(data.toString())) {
                                node.status({
                                  fill: "blue",
                                  shape: "dot",
                                  text: " quering " + (data.toString())
                                });
                                return characteristic.read(function(error, value) {
                                  msg.payload[data.toString()] = value;
                                  return callback();
                                });
                              } else {
                                return callback();
                              }
                            });
                          } else {
                            return callback();
                          }
                        });
                      });
                    }), function(error) {
                      return callback();
                    });
                  }
                ], function(err, results) {
                  msg.payload.uuid = peripheral.uuid;
                  msg.payload.rssi = peripheral.rssi;
                  peripheral.disconnect();
                  node.active = false;
                  node.status({
                    fill: "green",
                    shape: "ring",
                    text: msg.payload.battery + "%, " + msg.payload.voltage + "v, " + peripheral.rssi + " dB"
                  });
                  return node.send(msg);
                });
              }
            });
          }
        });
      }
    });
  };

  RED = require(process.env.NODE_RED_HOME + "/red/red");

  noble = require("noble");

  async = require("async");

  RED.nodes.registerType("Bean", Bean);

}).call(this);