//
//  UserDataTests.swift
//  MobileMessagingExample
//
//  Created by Andrey K. on 14/07/16.
//

import XCTest
@testable import MobileMessaging

var darthVaderDateOfDeath: NSDate {
	let comps = NSDateComponents()
	comps.year = 1983
	comps.month = 5
	comps.day = 25
	comps.hour = 0
	comps.minute = 0
	comps.second = 0
	comps.timeZone = TimeZone(secondsFromGMT: 0) // has expected timezone
	comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
	return comps.date! as NSDate
}

var darthVaderDateOfBirth: Date {
    let comps = NSDateComponents()
    comps.year = 1980
    comps.month = 12
    comps.day = 12
    comps.hour = 0
    comps.minute = 0
    comps.second = 0
    comps.timeZone = TimeZone(secondsFromGMT: 0) // has expected timezone
    comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
    return comps.date!
}


class UserDataTests: MMTestCase {
	func testCustomUserDataPayloadConstructors() {
		//date
		do {
			let comps = NSDateComponents()
			comps.year = 2016
			comps.month = 12
			comps.day = 31
			comps.hour = 23
			comps.minute = 55
			comps.second = 00
			comps.timeZone = TimeZone(secondsFromGMT: 5*60*60) // has expected timezone
			comps.calendar = Calendar(identifier: Calendar.Identifier.gregorian)
			let date = comps.date!
			let request = UserDataRequest(applicationCode: "", pushRegistrationId: "", externalUserId: "any", predefinedUserData: ["name": "JohnDow"], customUserData: ["registrationDate": CustomUserDataValue(date: date as NSDate)])
			
			let expectedDict: NSDictionary = [
				Consts.APIKeys.UserData.predefinedUserData: [
					"name": "JohnDow"
				],
				Consts.APIKeys.UserData.customUserData: [
					"registrationDate" : [
						"type": "Date",
						"value": "2016-12-31T18:55:00Z"
					]
				]
			]
			XCTAssertTrue((request.body! as NSDictionary).isEqual(expectedDict))
		}
		
		// number
		do {
			let request = UserDataRequest(applicationCode: "", pushRegistrationId: "", externalUserId: "any", predefinedUserData: ["name": "JohnDow"], customUserData: ["bootsize": CustomUserDataValue(double: 9.5)])
			let expectedDict: NSDictionary = [
				Consts.APIKeys.UserData.predefinedUserData: [
					"name": "JohnDow"
				],
				Consts.APIKeys.UserData.customUserData: [
					"bootsize" : [
						"type": "Number",
						"value": 9.5
					]
				]
			]
			XCTAssertTrue((request.body! as NSDictionary).isEqual(expectedDict))
		}
		
		// null
		do {
			let request = UserDataRequest(applicationCode: "", pushRegistrationId: "", externalUserId: "any", predefinedUserData: ["name": "JohnDow"], customUserData: ["registrationDate": CustomUserDataValue(null: NSNull())])
			let expectedDict = [
				Consts.APIKeys.UserData.predefinedUserData: [
					"name": "JohnDow"
				],
				Consts.APIKeys.UserData.customUserData: [
					"registrationDate" : NSNull()
				]
			]
			XCTAssertTrue((request.body! as NSDictionary).isEqual(expectedDict))
		}
	}
	
	func testDataPersisting() {
		let currentUser = MobileMessaging.currentUser!
		currentUser.set(customData: CustomUserDataValue(string: "Crusher"), forKey: "nickname")
		currentUser.externalId = "someExternalId"
		currentUser.msisdn = "123"
		currentUser.email = "some@mail.com"
        currentUser.birthdate = darthVaderDateOfBirth
    	currentUser.persist()
    	
		XCTAssertEqual(currentUser.customData(forKey: "nickname")?.string, "Crusher")
		XCTAssertEqual(currentUser.customData?["nickname"]?.string, "Crusher")
		XCTAssertEqual(currentUser.externalId, "someExternalId")
		XCTAssertEqual(currentUser.msisdn, "123")
		XCTAssertEqual(currentUser.email, "some@mail.com")
		XCTAssertTrue(currentUser.predefinedData![MMUserPredefinedDataKeys.Gender.name] == nil, "custom data has nothing to do with predefined data")
        XCTAssertEqual(currentUser.predefinedData![MMUserPredefinedDataKeys.Birthdate.name], "1980-12-12")
		
		
		currentUser.set(customData: nil, forKey: "nilElement")
		XCTAssertTrue(currentUser.customData?["nilElement"]?.dataValue is NSNull)
		
		XCTAssertEqual(Date(timeIntervalSince1970: 1468593199).toJSON(), "2016-07-15")

		let ctx = (self.mobileMessagingInstance.internalStorage.mainThreadManagedObjectContext!)
		ctx.reset()
		if let installation = InstallationManagedObject.MM_findFirstInContext(ctx) {
			
			XCTAssertTrue(installation.dirtyAttributesSet.contains(AttributesSet.externalUserId))
			XCTAssertTrue(installation.dirtyAttributesSet.contains(AttributesSet.predefinedUserData))
			XCTAssertTrue(installation.dirtyAttributesSet.contains(AttributesSet.customUserData))
			
			XCTAssertEqual(installation.customUserData?["nickname"] as? String, "Crusher")
			XCTAssertEqual(installation.predefinedUserData![MMUserPredefinedDataKeys.MSISDN.name] as? String, "123")
            XCTAssertEqual(installation.predefinedUserData![MMUserPredefinedDataKeys.Birthdate.name] as? String, "1980-12-12")
			XCTAssertEqual(installation.predefinedUserData![MMUserPredefinedDataKeys.Email.name] as? String, "some@mail.com")
			XCTAssertTrue(currentUser.predefinedData!["nickname"] == nil, "custom data has nothing to do with predefined data")
			
			installation.resetDirtyAttribute(attributes: AttributesSet.customUserData)
			XCTAssertFalse(installation.dirtyAttributesSet.contains(AttributesSet.customUserData))
			
		} else {
			XCTFail("There must be atleast one installation object in database")
		}
	}
	
	func testSetupPredefinedAndCustomData() {
		weak var expectation = self.expectation(description: "save completed")
		
		//Precondiotions
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let currentUser = MobileMessaging.currentUser!

		currentUser.set(customData: "Death Star", forKey: "home")
		currentUser.set(customData: "Beer", forKey: "drink")
		currentUser.set(customData: "Pizza", forKey: "food")
		currentUser.set(customData: 189.5, forKey: "height")
		
		currentUser.firstName = "Darth"
		currentUser.lastName = "Vader"
		currentUser.birthdate = darthVaderDateOfBirth
		currentUser.gender = .Male

		currentUser.msisdn = "79214444444"
		currentUser.email = "darth@vader.com"
	
        XCTAssertTrue(currentUser.isChanged)
        
		currentUser.save { (error) in
			XCTAssertNil(error)
            
			XCTAssertFalse(currentUser.isChanged)
			XCTAssertEqual(currentUser.firstName, "Darth")
			XCTAssertEqual(currentUser.lastName, "Vader")
			XCTAssertEqual(currentUser.birthdate, darthVaderDateOfBirth)
			XCTAssertEqual(currentUser.gender, .Male)
			XCTAssertEqual(currentUser.msisdn, "79214444444")
			XCTAssertEqual(currentUser.email, "darth@vader.com")
			
			
			XCTAssertEqual(currentUser.customData?["nativePlace"]?.string, "Tatooine")
			XCTAssertEqual(currentUser.customData?["mentor"]?.string, "Obi Wan Kenobi")
			XCTAssertEqual(currentUser.customData?["home"]?.string, "Death Star")
			XCTAssertEqual(currentUser.customData?["drink"]?.string, "Beer")
			XCTAssertEqual(currentUser.customData?["food"]?.string, "Pizza")
			XCTAssertEqual(currentUser.customData?["height"]?.number, 189.5)
			XCTAssertEqual(currentUser.customData?["height"]?.double, 189.5)
			XCTAssertEqual(currentUser.customData?["height"]?.integer, nil)
			XCTAssertEqual(currentUser.customData?["dateOfDeath"]?.date, darthVaderDateOfDeath)
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 20, handler: nil)
	}

	func testThatFetchedUserDataIgnoredIfHasUnsyncedLocalChanges() {
		cleanUpAndStop()
		startWithCorrectApplicationCode()
		weak var expectation = self.expectation(description: "data received")
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		MobileMessaging.currentUser?.firstName = "John" // unsynced local change
		MobileMessaging.currentUser?.fetchFromServer { (error) in
			expectation?.fulfill()
		}

		waitForExpectations(timeout: 20, handler: { _ in
			XCTAssertEqual(MobileMessaging.currentUser?.firstName, "John") // must be preserved
		})
	}
	
	func testDeletePredefinedAndCustomData() {
		weak var expectation = self.expectation(description: "data received")
		
		//Precondiotions
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let currentUser = MobileMessaging.currentUser!
		currentUser.msisdn = nil
		currentUser.firstName = nil
		currentUser.gender = nil
		currentUser.set(customData: nil, forKey: "height")
		
		currentUser.save { (error) in
			XCTAssertNil(error)
			
			XCTAssertEqual(currentUser.firstName, "Darth")
			XCTAssertEqual(currentUser.lastName, "Vader")
			XCTAssertEqual(currentUser.birthdate, darthVaderDateOfBirth)
			XCTAssertEqual(currentUser.gender, UserGender.Male)
			XCTAssertNil(currentUser.msisdn)
			XCTAssertEqual(currentUser.email, "darth@vader.com")
			
			XCTAssertEqual(currentUser.customData?["nativePlace"]?.string, "Tatooine")
			XCTAssertEqual(currentUser.customData?["mentor"]?.string, "Obi Wan Kenobi")
			XCTAssertEqual(currentUser.customData?["home"]?.string, "Death Star")
			XCTAssertEqual(currentUser.customData?["drink"]?.string, "Beer")
			XCTAssertEqual(currentUser.customData?["food"]?.string, "Pizza")
			XCTAssertEqual(currentUser.customData?["dateOfDeath"]?.date, darthVaderDateOfDeath)
			XCTAssertNil(currentUser.customData?["height"])
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testThatInvalidPredefinedDataHandledProperly() {
		weak var expectation = self.expectation(description: "data received")
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		let currentUser = MobileMessaging.currentUser!
		currentUser.msisdn = "9697162937"
		currentUser.email = "john@mail,com"
		currentUser.save { (error) in
            
			XCTAssert(error!.localizedDescription.contains("50017") && error!.localizedDescription.contains("Invalid email"))
			
			// these two assertions assure us that user data response was consideded successfull and server state response was saved
			XCTAssertEqual(currentUser.msisdn, "79697162937")
			XCTAssertEqual(currentUser.email, "john@mail.com")
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 60, handler: nil)
	}
	
	func testGetPredefinedAndCustomData() {
		weak var expectation = self.expectation(description: "data received")
		
		//Precondiotions
		mobileMessagingInstance.currentUser.pushRegistrationId = MMTestConstants.kTestCorrectInternalID
		
		let currentUser = MobileMessaging.currentUser!
		
		currentUser.fetchFromServer { (error) in
			XCTAssertNil(error)
			
			XCTAssertEqual(currentUser.firstName, "Darth")
			XCTAssertEqual(currentUser.lastName, "Vader")
			XCTAssertEqual(currentUser.birthdate, darthVaderDateOfBirth)
			XCTAssertEqual(currentUser.gender, UserGender.Male)
			XCTAssertEqual(currentUser.email, "darth@vader.com")
			
			XCTAssertEqual(currentUser.customData?["nativePlace"]?.string, "Tatooine")
			XCTAssertEqual(currentUser.customData?["mentor"]?.string, "Obi Wan Kenobi")
			XCTAssertEqual(currentUser.customData?["home"]?.string, "Death Star")
			XCTAssertEqual(currentUser.customData?["drink"]?.string, "Beer")
			XCTAssertEqual(currentUser.customData?["food"]?.string, "Pizza")
			XCTAssertEqual(currentUser.customData?["dateOfDeath"]?.date, darthVaderDateOfDeath)
			expectation?.fulfill()
		}
		
		waitForExpectations(timeout: 10, handler: nil)
	}
	
	func testSetPredefinedData() {
		
		let currentUser = MobileMessaging.currentUser!
		
		currentUser.predefinedData = [
			MMUserPredefinedDataKeys.LastName.name: "Skywalker",
			MMUserPredefinedDataKeys.Gender.name: "M",
		]
		
		XCTAssertEqual(currentUser.predefinedData?.count, 2)
		XCTAssertEqual(currentUser.predefinedData?[MMUserPredefinedDataKeys.LastName.name], "Skywalker")
		XCTAssertEqual(currentUser.predefinedData?[MMUserPredefinedDataKeys.Gender.name], "M")
		
		currentUser.predefinedData = [
			MMUserPredefinedDataKeys.FirstName.name: "Luke",
			MMUserPredefinedDataKeys.Email.name: "luke@starwars.com",
		]
		
		XCTAssertEqual(currentUser.predefinedData?.count, 2)
		XCTAssertEqual(currentUser.predefinedData?[MMUserPredefinedDataKeys.FirstName.name], "Luke")
		XCTAssertEqual(currentUser.predefinedData?[MMUserPredefinedDataKeys.Email.name], "luke@starwars.com")
	}
	
	func testThatUserDataIsNotPersistedIfPrivacySettingsSpecified() {
		MobileMessaging.privacySettings.userDataPersistingDisabled = true
		
		let currentUser = MobileMessaging.currentUser!
		
		currentUser.predefinedData = [
			MMUserPredefinedDataKeys.LastName.name: "Skywalker",
			MMUserPredefinedDataKeys.Gender.name: "M",
		]
		currentUser.email = "luke@starwars.com"
		currentUser.msisdn = "123"
		currentUser.pushRegistrationId = "123"
		currentUser.externalId = "123"
		
		currentUser.set(customData: "Death Star", forKey: "home")
		
		currentUser.persist()
		
		// assertions:
		let ctx = self.mobileMessagingInstance.currentInstallation.coreDataProvider.context
		ctx.performAndWait {
			let installation = InstallationManagedObject.MM_findFirstInContext(ctx)!
			XCTAssertNil(installation.predefinedUserData, "userdata must not be persisted")
			XCTAssertNil(installation.customUserData, "userdata must not be persisted")
			XCTAssertNil(installation.externalUserId, "userdata must not be persisted")
			XCTAssertEqual(installation.internalUserId, "123", "internal id must be persisted, since it's not an user data")
		}
		
		XCTAssertEqual(currentUser.pushRegistrationId, "123")
		XCTAssertEqual(currentUser.email, "luke@starwars.com")
		XCTAssertEqual(currentUser.msisdn, "123")
		XCTAssertEqual(currentUser.externalId, "123")
		XCTAssertEqual(currentUser.predefinedData!, [
			MMUserPredefinedDataKeys.LastName.name: "Skywalker",
			MMUserPredefinedDataKeys.Gender.name: "M",
			MMUserPredefinedDataKeys.Email.name: "luke@starwars.com",
			MMUserPredefinedDataKeys.MSISDN.name: "123"
		])
		
		XCTAssertEqual(currentUser.customData(forKey: "home")?.string, "Death Star")
	}
	
	//TODO: test that user data is sent during unstallation sync only if changed
}
