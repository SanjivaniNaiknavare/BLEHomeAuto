import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue/flutter_blue.dart';
import 'package:ble_home_auto/global.dart' as global;
import 'package:geolocator/geolocator.dart';


class BeaconScreenForAllDevices extends StatefulWidget
{
  BeaconScreenForAllDevices({Key key}) : super(key: key);

  @override
  _BeaconScreenForAllDevicesState createState() => _BeaconScreenForAllDevicesState();
}

class _BeaconScreenForAllDevicesState extends State<BeaconScreenForAllDevices>  {

  String LOGTAG="BeaconScreenForAllDevices";

  BluetoothDevice mDevice;
  FlutterBlue flutterBlue;
  var scanSubscription;
  var deviceStateSubscription;
  bool isDeviceConnected=false;


  static String SERVICE_UUID="2141a8d3-8277-4652-b3bb-3ab55199182f";
  static String WIFI_CHAR="cbb9326e-0f1b-448c-955f-19dba2cb27e8";
  static String SSID_DESC="1d0bd9c6-16ab-46f0-bfc5-e4f99850ad58";    //Read,write
  static String PASS_DESC="1d0bd9c6-16ab-46f0-bfc5-e4f99850ad59";    //Read,write

  static String AUTH_CHAR="6a4a0be0-9e7f-46de-ab66-7cdf44ca6f31";
  static String TOKEN_DESC="723a1d75-d264-4135-901c-96ea33c6fa02";   //Read

  static String DEV_DET_CHAR="57a4c804-d1a0-4ed0-bbf5-997a3d6c5020";
  static String DEVID_DESC="f39376fc-9da9-4397-8cd9-e00ecc177714";   //Read
  static String MODEL_DESC="f39376fc-9da9-4397-8cd9-e00ecc177715";   //Read

  @override
  void initState(){
    super.initState();


  }


  @override
  Future<void> dispose() async {
    // TODO: implement dispose

    super.dispose();
  }


  /*
  * Function to start BLE Scan->
  *   It also checks if location service of the phone is enabled or not
  *   It also checks if bluetooth service of the phone is enabled or not
  *   It request for scanning BLE devices, only after location and bluetooth is enabled on phone
  */
  void startBLEScan() async
  {

    flutterBlue = FlutterBlue.instance;
    bool isLocationServiceEnabled  = await Geolocator.isLocationServiceEnabled();  // Geolocator plugin is used to if location service is enabled

    if(!isLocationServiceEnabled)
    {
      print(LOGTAG+"Please Turn On Device Location");
    }

    if(flutterBlue.isScanning != null)
    {
      flutterBlue.stopScan();
    }


    FlutterBlue.instance.state.listen((state) async
    {
      if (state == BluetoothState.off)
      {
        print(LOGTAG+"Please Turn On Device Bluetooth");
      }
      else if (state == BluetoothState.on)
      {
        bool isBLEOn=await FlutterBlue.instance.isOn;
        if(isBLEOn)
        {
          scanForDevices();
        }
        else
        {
          print(LOGTAG+"Please Turn On Device Bluetooth");
        }
      }
    });
  }

  /*
  * Function to scan BLE devices
  */
  void scanForDevices() async
  {

    if(flutterBlue.isScanning != null)
    {
      flutterBlue.stopScan();
    }

    scanSubscription = flutterBlue.scan(scanMode:ScanMode.lowLatency,allowDuplicates: true).listen((scanResult) async
    {

      ////Methods to get device name,MAC_Add, RSSI, Advertising Data from scanned devices

      String name = scanResult.device.name.toString();
      String mac_add = scanResult.device.id.toString();
      int rssi = scanResult.rssi;
      bool isConnectable = scanResult.advertisementData.connectable;
      List<int> scanList = new List();

      AdvertisementData adv_data = scanResult.advertisementData;
      for (var entry in adv_data.manufacturerData.entries)
      {
        scanList = entry.value;
      }

    }
    );
  }


  /*
  * Function to stop the BLE Scanning
  */
  void stopBLEScan() async
  {
    if(flutterBlue!=null)
    {
      if (flutterBlue.isScanning != null)
      {
        flutterBlue.stopScan();
      }
    }
  }


  /*
  * Function to connect to BLE device
  */
  Future<void> connectToDevice(BluetoothDevice device) async
  {
    mDevice=device;

    // listen to the state of the device
    deviceStateSubscription = mDevice.state.listen((s)
    {

      print(LOGTAG+" connection state->"+s.toString());

      if (s == BluetoothDeviceState.connected)
      {
        isDeviceConnected=true;
        print(LOGTAG+" device connected");
      }
      else if (s == BluetoothDeviceState.disconnected)
      {
        isDeviceConnected=false;
        print(LOGTAG+" device disconnected");
      }
    });


    // connect to device
    await mDevice.connect(timeout:Duration(seconds: 20),autoConnect: false).catchError((error, stackTrace)
    {

      isDeviceConnected=false;
      discoverDeviceServices();
      print(LOGTAG+" error in connection");

    }).timeout(Duration(seconds: 20),onTimeout: (){

      isDeviceConnected=false;
      print(LOGTAG+" timeout error");

    });

  }

  /*
  * Function to discover services of devices, only after connection is successful
  */
  void discoverDeviceServices() async
  {

    List<BluetoothService> services = await mDevice.discoverServices();
    services.forEach((service) async
    {
      var characteristics = service.characteristics;
      for (BluetoothCharacteristic c in characteristics)
      {

        if (c.uuid.toString().compareTo(WIFI_CHAR) == 0)
        {

          List<BluetoothDescriptor> descList=c.descriptors;
          for(int m=0;m<descList.length;m++)
          {
            BluetoothDescriptor tempDesc=descList.elementAt(m);

            if (tempDesc.uuid.toString().compareTo(SSID_DESC) == 0)
            {
              String wifiSSID="iobottech";
              List<int> byteData = utf8.encode(wifiSSID);
              writeDesc(tempDesc, byteData);      // write WIFI SSID to SSID_DESC
            }
            if (tempDesc.uuid.toString().compareTo(PASS_DESC) == 0)
            {
              String wifiPass="Io402##YO";
              List<int> byteData = utf8.encode(wifiPass);
              writeDesc(tempDesc, byteData);      // write WIFI Password to PASS_DESC
            }
          }
        }

        if (c.uuid.toString().compareTo(AUTH_CHAR) == 0)
        {
          List<BluetoothDescriptor> descList=c.descriptors;
          for(int m=0;m<descList.length;m++)
          {
            BluetoothDescriptor tempDesc = descList.elementAt(m);
            if (tempDesc.uuid.toString().compareTo(TOKEN_DESC) == 0)
            {
              readDesc(tempDesc); // read TOKEN_DESC to get authorization token, only after writing WiFi SSID and Password to descriptors
            }
          }
        }

        if (c.uuid.toString().compareTo(DEV_DET_CHAR) == 0)
        {
          List<BluetoothDescriptor> descList=c.descriptors;
          for(int m=0;m<descList.length;m++)
          {
            BluetoothDescriptor tempDesc = descList.elementAt(m);
            if (tempDesc.uuid.toString().compareTo(DEVID_DESC) == 0)
            {
              readDesc(tempDesc); // read DEVID_DESC to get device id, only after writing WiFi SSID and Password to descriptors
            }
            if (tempDesc.uuid.toString().compareTo(MODEL_DESC) == 0)
            {
              readDesc(tempDesc); // read DEVID_DESC to get device model, only after writing WiFi SSID and Password to descriptors
            }
          }
        }

      }
    }
    );
  }


  /*
  * Function to write descriptor
  */
  void writeDesc(BluetoothDescriptor descriptor,List<int> data) async
  {

    if(isDeviceConnected)
    {
      descriptor.write(data).then((value) =>
      ({

        print(LOGTAG + " write desc->" + value.toString()),
        readDesc(descriptor),

      })).catchError((error, stackTrace) {
        print(LOGTAG+" error in write desc");
      });
    }
    else
    {
      print(LOGTAG+" device is disconnected");
    }
  }


  /*
  * Function to read descriptor
  */
  void readDesc(BluetoothDescriptor descriptor) async
  {

    if(isDeviceConnected)
    {
      String convertedStr = "";

      descriptor.read().then((value) async =>
      ({

        print(LOGTAG + " read desc->" + value.toString()),

        convertedStr = new String.fromCharCodes(value).toString(),
        print(convertedStr.toString()),

      }));
    }
    else
    {
      print(LOGTAG+" device is disconnected");
    }
  }

  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    return Scaffold(
        body: new Container()
    );
  }



}
