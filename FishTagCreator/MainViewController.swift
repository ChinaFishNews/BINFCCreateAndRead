/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The view controller that creates an NFC tag for fish.
*/

import UIKit
import CoreNFC
import os

class MainViewController: UITableViewController, UINavigationControllerDelegate, NFCNDEFReaderSessionDelegate {
 
    // MARK: - Properties
    let fishKinds = [String](arrayLiteral: "Creative Salmon", "Amazing Tuna", "Dancing Mahi-Mahi", "Incredible Bass")
    let priceBCD = [String](arrayLiteral: "0599", "1099", "1599") // BCD encoded price
    var readerSession: NFCNDEFReaderSession?
    var ndefMessage: NFCNDEFMessage?
 
    @IBOutlet weak var productPrice: UISegmentedControl!
    @IBOutlet weak var productDate: UIDatePicker!
    @IBOutlet weak var productKind: UIPickerView!
        
    // MARK: - Actions
    @IBAction func writeTag(_ sender: Any) {
        guard NFCNDEFReaderSession.readingAvailable else {
            let alertController = UIAlertController(
                title: "不支持扫描",
                message: "这个设备不支持标签扫描",
                preferredStyle: .alert
            )
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alertController, animated: true, completion: nil)
            return
        }
        
        readerSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        readerSession?.alertMessage = "Hold your iPhone near a writable NFC tag to update."
        readerSession?.begin()
    }
    
    // MARK: - Private functions
    func createURLPayload() -> NFCNDEFPayload? {
        var dateString: String?
        var priceString: String?
        var kindString: String?
        
        DispatchQueue.main.sync {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = "yyyyMMdd"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
            dateString = dateFormatter.string(from: self.productDate.date)
            
            kindString = fishKinds[productKind.selectedRow(inComponent: 0)]
            
            priceString = priceBCD[productPrice.selectedSegmentIndex]
        }
        
        var urlComponent = URLComponents(string: "https://www.baidu.com/")
        
//        urlComponent?.queryItems = [URLQueryItem(name: "date", value: dateString),
//                                    URLQueryItem(name: "kind", value: kindString),
//                                    URLQueryItem(name: "price", value: priceString)]
        // 数据超出限制，所以只存储date
        urlComponent?.queryItems = [URLQueryItem(name: "date", value: dateString)]
        
        os_log("url: %@", (urlComponent?.string)!)
        
        return NFCNDEFPayload.wellKnownTypeURIPayload(url: (urlComponent?.url)!)
    }
    
    func tagRemovalDetect(_ tag: NFCNDEFTag) {
        // In the tag removal procedure, you connect to the tag and query for
        // its availability. You restart RF polling when the tag becomes
        // unavailable; otherwise, wait for certain period of time and repeat
        // availability checking.
        self.readerSession?.connect(to: tag) { (error: Error?) in
            if error != nil || !tag.isAvailable {
                
                os_log("Restart polling")
                
                self.readerSession?.restartPolling()
                return
            }
            DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .milliseconds(500), execute: {
                self.tagRemovalDetect(tag)
            })
        }
    }
    
    // MARK: - NFCNDEFReaderSessionDelegate
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        let textPayload = NFCNDEFPayload.wellKnowTypeTextPayload(string: "Brought to you by the Great Fish Company", locale: Locale(identifier: "En"))
        let urlPayload = self.createURLPayload()
        ndefMessage = NFCNDEFMessage(records: [urlPayload!, textPayload!])
        os_log("MessageSize=%d", ndefMessage!.length)
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // If necessary, you may handle the error. Note session is no longer valid.
        // You must create a new session to restart RF polling.
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // Do not add code in this function. This method isn't called
        // when you provide `reader(_:didDetect:)`.
    }
    
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        if tags.count > 1 {
            session.alertMessage = "发现超过1个标签。请仅展示示1个标签"
            self.tagRemovalDetect(tags.first!)
            return
        }
        
        // You connect to the desired tag.
        let tag = tags.first!
        session.connect(to: tag) { (error: Error?) in
            if error != nil {
                session.restartPolling()
                return
            }
            
            // You then query the NDEF status of tag.
            tag.queryNDEFStatus() { (status: NFCNDEFStatus, capacity: Int, error: Error?) in
                if error != nil {
                    session.invalidate(errorMessage: "无法确定NDEF状态 请再试一次")
                    return
                }
                
                if status == .readOnly {
                    session.invalidate(errorMessage: "标签不可写")
                } else if status == .readWrite {
                    if self.ndefMessage!.length > capacity {
                        session.invalidate(errorMessage: "标签容量太小 最小尺寸要求\(self.ndefMessage!.length) 字节")
                        return
                    }
                    
                    // 当标签是可读写的并且有足够的容量时，写入一个NDEF消息
                    tag.writeNDEF(self.ndefMessage!) { (error: Error?) in
                        if error != nil {
                            session.invalidate(errorMessage: "更新标签失败了 请再试一次")
                        } else {
                            session.alertMessage = "更新成功!"
                            session.invalidate()
                        }
                    }
                } else {
                    session.invalidate(errorMessage: "标签不是NDEF格式")
                }
            }
        }
    }
}

