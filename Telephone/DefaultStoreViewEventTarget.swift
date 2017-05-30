//
//  DefaultStoreViewEventTarget.swift
//  Telephone
//
//  Copyright © 2008-2016 Alexey Kuznetsov
//  Copyright © 2016-2017 64 Characters
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

import Foundation

final class DefaultStoreViewEventTarget {
    fileprivate(set) var state: StoreViewState = StoreViewStateNoProducts()
    fileprivate var products: [Product] = []
    fileprivate var fetchError = ""

    fileprivate let factory: StoreUseCaseFactory
    fileprivate let restoration: UseCase
    fileprivate let refresh: UseCase
    fileprivate let presenter: StoreViewPresenter

    init(factory: StoreUseCaseFactory, purchaseRestoration: UseCase, receiptRefresh: UseCase, presenter: StoreViewPresenter) {
        self.factory = factory
        self.restoration = purchaseRestoration
        self.refresh = receiptRefresh
        self.presenter = presenter
    }
}

extension DefaultStoreViewEventTarget: StoreViewStateMachine {
    func changeState(_ newState: StoreViewState) {
        state = newState
    }

    func checkPurchase() {
        factory.makePurchaseCheckUseCase(output: self).execute()
        presenter.showPurchaseCheckProgress()
    }

    func fetchProducts() {
        factory.makeProductsFetchUseCase(output: self).execute()
        presenter.showProductsFetchProgress()
    }

    func show(_ products: [Product]) {
        self.products = products
        presenter.show(products)
    }

    func showProductsFetchError(_ error: String) {
        fetchError = error
        presenter.showProductsFetchError(error)
    }

    func purchaseProduct(withIdentifier identifier: String) {
        do {
            try factory.makeProductPurchaseUseCase(identifier: identifier).execute()
        } catch {
            print("Could not make purchase: \(error)")
        }
    }

    func showPurchaseProgress() {
        presenter.showPurchaseProgress()
    }

    func showCachedProductsAndPurchaseError(_ error: String) {
        showCachedProducts()
        presenter.showPurchaseError(error)
    }

    func showCachedProducts() {
        presenter.show(products)
    }

    func restorePurchases() {
        restoration.execute()
        presenter.showPurchaseRestorationProgress()
    }

    func refreshReceipt() {
        refresh.execute()
    }

    func showCachedProductsAndRestoreError(_ error: String) {
        showCachedProducts()
        presenter.showPurchaseRestorationError(error)
    }

    func showCachedFetchErrorAndRestoreError(_ error: String) {
        showCachedFetchError()
        presenter.showPurchaseRestorationError(error)
    }

    func showCachedFetchError() {
        presenter.showProductsFetchError(fetchError)
    }

    func showThankYou(expiration: Date) {
        presenter.showPurchased(until: expiration)
    }
}
