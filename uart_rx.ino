#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Must perfectly match the UUIDs in your AbacusBLEManager.swift
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define CHARACTERISTIC_UUID "abcdef01-1234-5678-1234-56789abcdef0"

// UART pins connecting to the Cyclone IV
#define RXD2 16
#define TXD2 17

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Connection callbacks to manage BLE state
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("iPhone Connected!");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("iPhone Disconnected.");
    }
};

void setup() {
  Serial.begin(115200); // For debugging to your Mac/PC
  
  // Start Hardware Serial to read from the FPGA
  Serial2.begin(115200, SERIAL_8N1, RXD2, TXD2);

  // Initialize the BLE device
  BLEDevice::init("Tactile Abacus");

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic with Notify properties
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_NOTIFY
                    );

  // Add the BLE2902 descriptor required for notifications in iOS
  pCharacteristic->addDescriptor(new BLE2902());

  // Start the service
  pService->start();

  // Start broadcasting
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();
  
  Serial.println("BLE Server is running. Waiting for connection...");
}

void loop() {
  // 1. Handle BLE Reconnections
  if (!deviceConnected && oldDeviceConnected) {
      delay(500); // Give the Bluetooth stack a moment to reset
      pServer->startAdvertising(); 
      Serial.println("Restarted advertising...");
      oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }

  // 2. Read UART data from the FPGA (Wait for exactly 4 bytes)
  if (deviceConnected && Serial2.available() >= 4) {
      
      // Read the bytes in Big-Endian order (as sent by your Verilog uart_tx)
      uint8_t b1 = Serial2.read(); // MSB [31:24]
      uint8_t b2 = Serial2.read(); //     [23:16]
      uint8_t b3 = Serial2.read(); //     [15:8]
      uint8_t b4 = Serial2.read(); // LSB [7:0]

      // Reconstruct the 32-bit math total
      uint32_t abacus_value = (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
      
      Serial.print("Received from FPGA: ");
      Serial.println(abacus_value);

      // Push the value over Bluetooth to the iPhone
      // iOS expects Little-Endian, which matches the ESP32's native memory layout
      pCharacteristic->setValue((uint8_t*)&abacus_value, sizeof(abacus_value));
      pCharacteristic->notify();
  }
}