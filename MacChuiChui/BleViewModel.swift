//
//  BleViewModel.swift
//  HeartRateMonitor
//
//  Created by Srun Zhou on 2020/5/12.
//  Copyright © 2020 Srun Zhou. All rights reserved.
//

import UIKit
import Foundation
import Combine
import CoreBluetooth
import Telegraph


final class BleViewModel: ObservableObject {
    
    @Published var isScan = false
    @Published var status = "Not Start"
    @Published var isNetError = false
    @Published var uuid = ""
    @Published var isSaveMoneyMode = false
    
    var cbController:CBController? = nil
}

class CBController:NSObject, CBPeripheralDelegate{
    let dingdingServiceUUID          = CBUUID(string: ServiceIdentifiers.dingdingServiceUUIDString)
    
    var cbManager:CBCentralManager? = nil
    
    var viewModel:BleViewModel? = nil
    
    var mPeripheral:CBPeripheral? = nil
    
    
    var call:AnyCancellable? = nil
    var connectCall:AnyCancellable? = nil
    
    var isSuccess = false
    
    var lastManufacturerDataString = ""
    
    var serverHTTP = Server()
    
    init(cbManager:CBCentralManager,viewModel:BleViewModel) {
        self.cbManager = cbManager
        self.viewModel = viewModel
    }
    
    func initServer(){
        try! serverHTTP.start(port: 9000)
        serverHTTP.route(.POST, "/getUUID", getUUID)
    }
    
    func getUUID(request: HTTPRequest) -> HTTPResponse {
        let bodyObject: [String : Any] = [
            "service": "",
            "data": lastManufacturerDataString,
            "priority": "Higgggg"
        ]
        
        let bodyData = try! JSONSerialization.data(withJSONObject: bodyObject, options: [])
        
        return HTTPResponse( .ok, body: bodyData)
    }
    
    func sinkScan() {
        self.cbManager?.delegate = self
        
        self.call = viewModel!.$isScan.sink(){
            if ($0){
                self.cbManager!.scanForPeripherals(withServices: [self.dingdingServiceUUID], options: nil)
            }else{
                if self.cbManager!.isScanning{
                    self.cbManager!.stopScan()
                }
            }
        }
        
    }
    
}

extension CBController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // In your application, you would address each possible value of central.state and central.authorization
        switch central.state {
        case .resetting:
            print("Connection with the system service was momentarily lost. Update imminent")
        case .unsupported:
            print("Platform does not support the Bluetooth Low Energy Central/Client role")
        case .unauthorized:
            print("The application is not authorized to use the Bluetooth Low Energy role")
        case .poweredOff:
            print("Bluetooth is currently powered off")
        case .poweredOn:
            print("Starting cbManager")
            
        default:
            print("Cleaning up cbManager")
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        
        print("Find device")
        for data in advertisementData {
            if data.key == "kCBAdvDataManufacturerData" {
            
                let manufacurerString = (data.value as! Data).hexEncodedString().dropFirst(4)
                
                if self.lastManufacturerDataString != manufacurerString {
                    viewModel?.status = "Found a new data"
                    lastManufacturerDataString = String(manufacurerString)
                    viewModel?.uuid = lastManufacturerDataString
                    print(lastManufacturerDataString)
                    let date = Date()
                    let calendar = Calendar.current
                    
                    let hour = calendar.component(.hour, from: date)
                    
                    if self.viewModel!.isSaveMoneyMode {
                        if (hour >= 8 && hour < 10) || (hour >= 18 && hour < 21) {
                            sendRequest(lastManufacturerDataString)
                        } else {
                            viewModel?.status = "Not at time"
                        }
                    } else {
                        sendRequest(lastManufacturerDataString)
                    }
                }
            }
        }
        
    }
    

    
}


extension CBController {
    
    func sendRequest(_ content:String) {
        let sessionConfig = URLSessionConfiguration.default
        
        let session = URLSession(configuration: sessionConfig, delegate: nil, delegateQueue: nil)

        guard var URL = URL(string: "https://my-shadows.an.r.appspot.com/uuid") else {return}
        let URLParams = [
            "uuid": "12",
        ]
        URL = URL.appendingQueryParameters(URLParams)
        var request = URLRequest(url: URL)
        request.httpMethod = "POST"

        // Headers

        request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")

        // JSON Body

        let bodyObject: [String : Any] = [
            "service": "",
            "data": content,
            "priority": "Higgggg"
        ]
        request.httpBody = try! JSONSerialization.data(withJSONObject: bodyObject, options: [])

        /* Start a new Task */
        let task = session.dataTask(with: request, completionHandler: { (data: Data?, response: URLResponse?, error: Error?) -> Void in
            if (error == nil) {
                // Success
                let statusCode = (response as! HTTPURLResponse).statusCode
                print("URL Session Task Succeeded: HTTP \(statusCode)")
                
                self.viewModel?.status = "Upload Success"
            }
            else {
                // Failure
                print("URL Session Task Failed: %@", error!.localizedDescription);
                
                self.viewModel?.status = "Upload Failed"
            }
        })
        task.resume()
        session.finishTasksAndInvalidate()
    }


    
    
    func dataToDictionary(data:Data) ->Dictionary<String, String>?{
        do{
            let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers)
            let dic = json as! Dictionary<String, String>
            
            return dic
        }catch _ {
            return nil
        }
        
    }
}

extension Data {
    init?(hexString: String) {
        let len = hexString.count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = hexString.index(hexString.startIndex, offsetBy: i*2)
            let k = hexString.index(j, offsetBy: 2)
            let bytes = hexString[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                return nil
            }
        }
        self = data
    }
    
    struct HexEncodingOptions: OptionSet {
        let rawValue: Int
        static let upperCase = HexEncodingOptions(rawValue: 1 << 0)
    }

    func hexEncodedString(options: HexEncodingOptions = []) -> String {
        let format = options.contains(.upperCase) ? "%02hhX" : "%02hhx"
        return map { String(format: format, $0) }.joined()
    }
}

protocol URLQueryParameterStringConvertible {
    var queryParameters: String {get}
}

extension Dictionary : URLQueryParameterStringConvertible {
    /**
     This computed property returns a query parameters string from the given NSDictionary. For
     example, if the input is @{@"day":@"Tuesday", @"month":@"January"}, the output
     string will be @"day=Tuesday&month=January".
     @return The computed parameters string.
    */
    var queryParameters: String {
        var parts: [String] = []
        for (key, value) in self {
            let part = String(format: "%@=%@",
                String(describing: key).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!,
                String(describing: value).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
            parts.append(part as String)
        }
        return parts.joined(separator: "&")
    }
    
}

extension URL {
    /**
     Creates a new URL by adding the given query parameters.
     @param parametersDictionary The query parameter dictionary to add.
     @return A new URL.
    */
    func appendingQueryParameters(_ parametersDictionary : Dictionary<String, String>) -> URL {
        let URLString : String = String(format: "%@?%@", self.absoluteString, parametersDictionary.queryParameters)
        return URL(string: URLString)!
    }
}

