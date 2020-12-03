//
//  IAPViewController.swift
//  TreasureDataExample
//
//  Created by huylenq on 3/7/19.
//  Copyright © 2019 Arm Treasure Data. All rights reserved.
//

import UIKit
import StoreKit


class IAPViewController : UITableViewController, SKProductsRequestDelegate, SKPaymentTransactionObserver
{
    var products: [SKProduct] = []
    let indicator = UIActivityIndicatorView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
    
    override func viewDidLoad() {
        indicator.center = CGPoint(x: self.view.center.x, y: self.view.center.y * 0.3)
        indicator.color = .gray
        indicator.hidesWhenStopped = true
        indicator.startAnimating()
        self.view.addSubview(indicator)
        
        requestProducts()
    }

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction])
    {  
        for transaction in transactions {
            if (transaction.transactionState != .purchasing) {
                queue.finishTransaction(transaction)
            }
        }
    }
    
    @IBAction func purchase(_ sender: UIButton) {
        (self.parent as! iOSViewController).updateClientIfFormChanged()

        let product = products[sender.tag]
        SKPaymentQueue.default().add(SKPayment(product: product))
    }

    public func requestProducts()
    {
        let request = SKProductsRequest(productIdentifiers: TreasureDataExample.productIds())
        request.delegate = self
        request.start()
        SKPaymentQueue.default().add(self)
    }
    
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse)
    {
        self.products = response.products
        (self.view as? UITableView)?.separatorStyle = .singleLine
        indicator.stopAnimating()
        self.tableView.reloadData()
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int
    {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int
    {
        return products.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell
    {
        let cell = tableView.dequeueReusableCell(withIdentifier: "IAPItemCell") as! IAPItemCell
        
        cell.itemName.text = products[indexPath.row].localizedTitle
        cell.purchaseButton.tag = indexPath.row
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath)
    {
        let product = products[indexPath.row]
        let payment = SKMutablePayment(product: product)
        payment.quantity = 1
        SKPaymentQueue.default().add(payment)
    }
}

class IAPItemCell : UITableViewCell
{
    @IBOutlet weak var itemName: UILabel!
    @IBOutlet weak var purchaseButton: UIButton!
}
