//
//  DynamicBaseUrlTests.swift
//  MobileMessagingExample
//
//  Created by Andrey Kadochnikov on 24/11/2017.
//
import XCTest
import Foundation
@testable import MobileMessaging

class DynamicBaseUrlBackingStorageStub: KVOperations {
	func get(key: String) -> Any? {
		return dynamicUrl
	}
	
	func cleanUp(forKey: String) {
		dynamicUrl = nil
	}
	
	func set(value: Any, key: String) {
		dynamicUrl = value
	}
	
	var dynamicUrl: Any? = nil
}

class DynamicBaseUrlStorageStub: DynamicBaseUrlStorage {
	init() {
		super.init(backingStorage: DynamicBaseUrlBackingStorageStub())
	}
}

class SessionManagerMock: DynamicBaseUrlHTTPSessionManager {
	typealias RequestResponseMap = (Any) -> (Any?, NSError?)
	var requestResponseMap: RequestResponseMap
	
	init(requestResponseMap: @escaping RequestResponseMap) {
		self.requestResponseMap = requestResponseMap
		super.init(baseURL: URL(string: "https://initial-stub.com"), sessionConfiguration: MobileMessaging.urlSessionConfiguration, appGroupId: "")
		self.storage = DynamicBaseUrlStorageStub()
	}
	
	override func performRequest<R>(_ request: R, sessionManager: MM_AFHTTPSessionManager, successBlock: @escaping (URLSessionDataTask, Any?) -> Void, failureBlock: @escaping (URLSessionDataTask?, Error) -> Void) where R : RequestData {
		
		let (anyResponse, error) = self.requestResponseMap(request)
		if let error = error {
			failureBlock(nil, error)
		} else {
			successBlock(URLSessionDataTask(), anyResponse as? R.ResponseType)
		}
	}
}

class DynamicBaseUrlTests: MMTestCase {

	func testThatNewBaseUrlIsAppliedForFollowingRequests() {
		let initialUrl = URL(string: "https://initial.com")!
		
		let sessionManager = DynamicBaseUrlHTTPSessionManager(baseURL: initialUrl, sessionConfiguration: nil, appGroupId: "")
		sessionManager.storage = DynamicBaseUrlStorageStub()
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://initial.com")
		
		// assert that DBU changed if a new one received
		let responseWithNewBaseUrl = HTTPURLResponse(url: initialUrl, statusCode: 200, httpVersion: nil, headerFields: [Consts.DynamicBaseUrlConsts.newBaseUrlHeader: "https://new.com"])
		sessionManager.handleDynamicBaseUrl(response: responseWithNewBaseUrl, error: nil)
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://new.com")
		
		// assert that DBU remains the same if new is not present
		let responseWithEmptyBaseUrl = HTTPURLResponse(url: initialUrl, statusCode: 200, httpVersion: nil, headerFields: nil)
		sessionManager.handleDynamicBaseUrl(response: responseWithEmptyBaseUrl, error: nil)
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://new.com")
		
		// assert that cached DBU restored after session reinitialization
		let newSessionManager = DynamicBaseUrlHTTPSessionManager(baseURL: initialUrl, sessionConfiguration: nil, appGroupId: "")
		newSessionManager.storage = DynamicBaseUrlStorageStub()
		XCTAssertEqual(sessionManager.dynamicBaseUrl?.absoluteString, "https://new.com")
		
		// assert that DBU reset if specific error happened
		newSessionManager.handleDynamicBaseUrl(response: nil, error: NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, userInfo: nil))
		XCTAssertEqual(newSessionManager.dynamicBaseUrl?.absoluteString, "https://initial.com")
	}
	
	func testThatWeDoRetryAfterCannotFindHost() {
		weak var registrationFinishedExpectation = expectation(description: "registration finished")
		weak var retriesStartedExpectation = expectation(description: "expectationRetriesStarted")
		let newDynamicURL = URL(string: "https://not-reachable-url.com")!
		cleanUpAndStop()
		var retriesStarted = false
		let mm = MobileMessaging.withApplicationCode("", notificationType: UserNotificationType(options: []) , backendBaseURL: Consts.APIValues.prodDynamicBaseURLString)!
		mm.apnsRegistrationManager = ApnsRegistrationManagerStub(mmContext: mm)
		MobileMessaging.httpSessionManager = SessionManagerMock(requestResponseMap: {
			// given: registration call returns NSURLErrorCannotFindHost error
			if $0 is RegistrationRequest {
				if retriesStarted == false {
					retriesStarted = true
					// here we make sure the very first attempt to register has been sent to a given dynamic base url
					XCTAssertEqual(MobileMessaging.httpSessionManager.dynamicBaseUrl, newDynamicURL)
					retriesStartedExpectation?.fulfill()
				} else {
					// here we make sure the dynamic base url was reset to original base url when retries started
					XCTAssertEqual(MobileMessaging.httpSessionManager.dynamicBaseUrl, MobileMessaging.httpSessionManager.originalBaseUrl)
				}
				return (nil, NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, userInfo: nil))
			} else {
				return (nil, nil)
			}
		})
		
		MobileMessaging.httpSessionManager.dynamicBaseUrl = newDynamicURL
		
		// make sure base urls prepared correctly
		XCTAssertEqual(MobileMessaging.httpSessionManager.dynamicBaseUrl, newDynamicURL)
		XCTAssertEqual(MobileMessaging.httpSessionManager.originalBaseUrl!.absoluteString, "https://initial-stub.com")
		XCTAssertNotEqual(MobileMessaging.httpSessionManager.dynamicBaseUrl, MobileMessaging.httpSessionManager.originalBaseUrl)
		
		mm.didRegisterForRemoteNotificationsWithDeviceToken("someToken123123123".data(using: String.Encoding.utf16)!) {  error in
			registrationFinishedExpectation?.fulfill()
		}
		
		self.waitForExpectations(timeout: 60) { _ in }
	}
}
