//
//  InteractiveNotifications.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 24.08.17.
//

import Foundation
import MobileMessaging

extension AppDelegate {
	func setupLogging() {
		MobileMessaging.logger?.logOutput = MMLogOutput.Console
		MobileMessaging.logger?.logLevel = .All
	}
	
	var customCategories: Set<NotificationCategory> {
		var categories = Set<NotificationCategory>()
		categories.insert(categoryShareCancel)
		if let _replyCategory = replyCategory {
			categories.insert(_replyCategory)
		}
		return categories
	}
	
	var categoryShareCancel: NotificationCategory {
		//Action with title "Cancel", which will be marked as destructive and will require device to be unlocked before proceed
		let cancelAction = NotificationAction(identifier: "cancel",
											  title: "Cancel",
											  options: [.destructive, .authenticationRequired])!
		//Action with title "Share", which will require device to be unlocked before proceed and will bring application to the foreground
		let shareAction = NotificationAction(identifier: "share",
											 title: "Share",
											 options: [.foreground, .authenticationRequired])!
		
		let category: NotificationCategory!
		if #available(iOS 10.0, *) {
			category = NotificationCategory(identifier: "category_share_cancel",
											actions: [shareAction, cancelAction],
											options: nil,
											intentIdentifiers: nil)
		} else {
			category = NotificationCategory(identifier: "category_share_cancel",
											actions: [shareAction, cancelAction],
											options: nil,
											intentIdentifiers: nil)
		}
		return category
	}
	
	var replyCategory: NotificationCategory? {
		if #available(iOS 9.0, *),
			let replyAction = TextInputNotificationAction(identifier: "reply", title: "Reply", options: [], textInputActionButtonTitle: "Reply", textInputPlaceholder: "print reply here") {
			return NotificationCategory(identifier: "category_reply",
										actions: [replyAction],
										options: nil,
										intentIdentifiers: nil)
		} else {
			return nil
		}
	}
}
