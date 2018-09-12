#include "MicroBit.h"
MicroBit uBit;
const int8_t CALIBRATED_POWERS[] = {-49, -37, -33, -28, -25, -20, -15, -10};
uint8_t advertising = 0;
uint8_t tx_power_level = 6;
uint8_t AdvData [26] = {0xff, 0xff,
                        0x55, 0x98,
                        0,
                        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
uint8_t buttonsState = 0;
uint8_t eventCounter = 0;

char digit(uint8_t n)
    {
    return '0' + n;
    }

void startAdvertising()
    {
    int connectable = 0;
    int interval = 160;
    uBit.bleManager.setTransmitPower(tx_power_level);
    uBit.bleManager.ble->setAdvertisingType(connectable ? GapAdvertisingParams::ADV_CONNECTABLE_UNDIRECTED : GapAdvertisingParams::ADV_NON_CONNECTABLE_UNDIRECTED);
    uBit.bleManager.ble->setAdvertisingInterval(interval);
    uBit.bleManager.ble->clearAdvertisingPayload();
    uBit.bleManager.ble->accumulateAdvertisingPayload(GapAdvertisingData::BREDR_NOT_SUPPORTED | GapAdvertisingData::LE_GENERAL_DISCOVERABLE);
    uBit.bleManager.ble->accumulateAdvertisingPayload(GapAdvertisingData::MANUFACTURER_SPECIFIC_DATA, AdvData, sizeof(AdvData));
    uBit.bleManager.ble->startAdvertising();
    uBit.display.printAsync("ULTIBO 98", 200);
    advertising = 1;
    }

void updatePayload ()
    {
    uBit.bleManager.ble->clearAdvertisingPayload();
    uBit.bleManager.ble->accumulateAdvertisingPayload(GapAdvertisingData::BREDR_NOT_SUPPORTED | GapAdvertisingData::LE_GENERAL_DISCOVERABLE);
    AdvData [4] = eventCounter;
    for (int i = 20; i >= 1; i--)
        {
        AdvData [i + 5] = AdvData [i + 5 - 1];
        }
    AdvData [5] = (buttonsState << 6);
    uBit.bleManager.ble->accumulateAdvertisingPayload(GapAdvertisingData::MANUFACTURER_SPECIFIC_DATA, AdvData, sizeof(AdvData));
    }

void stopAdvertising()
    {
    uBit.bleManager.stopAdvertising();
    uBit.display.scroll("OFF");
    advertising = 0;
    }

char text[] = "?";

void onButton(MicroBitEvent e)
    {
    uint8_t mask;
    uint8_t prev = buttonsState;
    if (e.source == MICROBIT_ID_BUTTON_A)
        mask = 0x01;

    if (e.source == MICROBIT_ID_BUTTON_B)
        mask = 0x02;

    if (e.source == MICROBIT_ID_BUTTON_AB)
        mask = 0x04;

    if (e.source == MICROBIT_ID_IO_P0)
        mask = 0x08;

    if (e.source == MICROBIT_ID_IO_P1)
        mask = 0x10;

    if (e.source == MICROBIT_ID_IO_P2)
        mask = 0x20;

    if (e.value == MICROBIT_BUTTON_EVT_DOWN)
        buttonsState |= mask;

    if (e.value == MICROBIT_BUTTON_EVT_UP)
        buttonsState &= ~mask;

    if (buttonsState != prev)
        {
        if (eventCounter == 255)
            {
            eventCounter = 128;
            }
        else
           {
           eventCounter = eventCounter + 1;
           }
        switch (buttonsState)
            {
            case 0:  text [0] = ' ';
                     break;
            case 1:  text [0] = 'A';
                     break;
            case 2:  text [0] = 'B';
                     break;
            case 3:  text [0] = '2';
                     break;
            default: text [0] = '?';
            }
        uBit.display.printAsync (text);
        updatePayload ();
        }

//  if (e.value == MICROBIT_BUTTON_EVT_CLICK)
//      uBit.serial.printf("CLICK");
//
//  if (e.value == MICROBIT_BUTTON_EVT_LONG_CLICK)
//      uBit.serial.printf("LONG_CLICK");
//
//  if (e.value == MICROBIT_BUTTON_EVT_HOLD)
//      uBit.serial.printf("HOLD");
//
//  if (e.value == MICROBIT_BUTTON_EVT_DOUBLE_CLICK)
//      uBit.serial.printf("DOUBLE_CLICK");
//
//  uBit.serial.printf("\r\n");
    }

int main()
    {
    uBit.init();
    uBit.messageBus.listen(MICROBIT_ID_BUTTON_A, MICROBIT_EVT_ANY, onButton);
    uBit.messageBus.listen(MICROBIT_ID_BUTTON_B, MICROBIT_EVT_ANY, onButton);
    startAdvertising();
    release_fiber();
    }
