//
//  StoreViewController.swift
//  Telephone
//
//  Copyright (c) 2008-2016 Alexey Kuznetsov
//  Copyright (c) 2016 64 Characters
//
//  Telephone is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  Telephone is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//

import Cocoa
import UseCases

final class StoreViewController: NSViewController {
    private var target: StoreViewEventTarget
    private dynamic var products: [PresentationProduct] = []

    @IBOutlet private var productsListView: NSView!
    @IBOutlet private var productsTableView: NSTableView!
    @IBOutlet private var productsFetchErrorView: NSView!
    @IBOutlet private var progressView: NSView!

    @IBOutlet private weak var productsContentView: NSView!
    @IBOutlet private weak var restorePurchasesButton: NSButton!
    @IBOutlet private weak var productsFetchErrorField: NSTextField!
    @IBOutlet private weak var progressIndicator: NSProgressIndicator!

    init(target: StoreViewEventTarget) {
        self.target = target
        super.init(nibName: "StoreViewController", bundle: nil)!
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        target.viewShouldReloadData(self)
    }

    func updateTarget(target: StoreViewEventTarget) {
        self.target = target
    }

    @IBAction func fetchProducts(sender: AnyObject) {
        target.viewDidStartProductFetch()
    }

    @IBAction func purchaseProduct(sender: NSButton) {
        target.viewDidMakePurchase(products[productsTableView.rowForView(sender)])
    }
}

extension StoreViewController: StoreView {
    func showProducts(products: [PresentationProduct]) {
        self.products = products
        showInProductsContentView(productsListView)
    }

    func showProductsFetchError(error: String) {
        productsFetchErrorField.stringValue = error
        showInProductsContentView(productsFetchErrorView)
    }

    func showProductsFetchProgress() {
        showProgress()
    }

    func showPurchaseProgress() {
        showProgress()
    }

    func showPurchaseError(error: String) {
        purchaseErrorAlert(withText: error).beginSheetModalForWindow(view.window!, completionHandler: nil)
    }

    func disablePurchaseRestoration() {
        restorePurchasesButton.enabled = false
    }

    func enablePurchaseRestoration() {
        restorePurchasesButton.enabled = true
    }

    private func showInProductsContentView(view: NSView) {
        productsContentView.subviews.forEach { $0.removeFromSuperview() }
        productsContentView.addSubview(view)
    }

    private func showProgress() {
        progressIndicator.startAnimation(self)
        showInProductsContentView(progressView)
    }
}

extension StoreViewController: NSTableViewDelegate {}

private func purchaseErrorAlert(withText text: String) -> NSAlert {
    let result = NSAlert()
    result.messageText = NSLocalizedString("Could not make purchase.", comment: "Product purchase error.")
    result.informativeText = text
    return result
}
