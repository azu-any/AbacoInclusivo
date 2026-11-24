#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// Keep your matching UUIDs here
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("iPhone Connected!");
    };
    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("iPhone Disconnected!");
    }
};

void setup() {
  Serial.begin(115200);
  Serial2.begin(115200, SERIAL_8N1, 16, 17); // RX2 = 16
  
  BLEDevice::init("Abacus");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
                    );
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0);
  BLEDevice::startAdvertising();
  
  Serial.println("Ready. Waiting for FPGA data and iPhone connection...");
}

void loop() {
  if (!deviceConnected && oldDeviceConnected) {
      delay(500);
      pServer->startAdvertising(); 
      oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }

  // Read the 4 bytes from the FPGA
  if (Serial2.available() >= 4) {
      uint8_t b1 = Serial2.read(); 
      uint8_t b2 = Serial2.read(); 
      uint8_t b3 = Serial2.read(); 
      uint8_t b4 = Serial2.read(); 

      uint32_t abacus_value = (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
      
      Serial.print("Received from FPGA: ");
      Serial.println(abacus_value);

      // Push to iPhone
      if (deviceConnected) {
          pCharacteristic->setValue((uint8_t*)&abacus_value, sizeof(abacus_value));
          pCharacteristic->notify();
      }
  }
}
