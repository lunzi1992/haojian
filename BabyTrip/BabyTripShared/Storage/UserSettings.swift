//
//  UserSettings.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//

import Foundation
import Combine

public class UserSettings: ObservableObject {
    public static let shared = UserSettings()
    
    private let userDefaults = UserDefaults.standard
    
    @Published public private(set) var babyProfile: BabyProfile?
    
    private let babyProfileKey = "BabyProfile"
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadProfile()
    }
    
    public func saveBabyProfile(_ profile: BabyProfile) {
        babyProfile = profile
        saveProfile()
    }
    
    public func hasProfile() -> Bool {
        return babyProfile != nil
    }
    
    private func saveProfile() {
        guard let profile = babyProfile else {
            userDefaults.removeObject(forKey: babyProfileKey)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(profile)
            userDefaults.set(data, forKey: babyProfileKey)
        } catch {
            print("Error saving baby profile: \(error)")
        }
    }
    
    private func loadProfile() {
        guard let data = userDefaults.data(forKey: babyProfileKey) else {
            return
        }
        
        do {
            let profile = try JSONDecoder().decode(BabyProfile.self, from: data)
            babyProfile = profile
        } catch {
            print("Error loading baby profile: \(error)")
        }
    }
}
