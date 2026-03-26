//
//  SettingsView.swift
//  BabyTrip
//
//  Created by BabyTrip Project
//

import SwiftUI
import BabyTripShared

struct SettingsView: View {
    @EnvironmentObject var userSettings: UserSettings
    @State private var showingEditProfile = false
    @State private var babyName = ""
    @State private var birthDate = Date()
    
    var body: some View {
        Form {
            Section("宝宝信息") {
                if let profile = userSettings.babyProfile {
                    HStack {
                        Text("宝宝姓名")
                        Spacer()
                        Text(profile.name.isEmpty ? "未设置" : profile.name)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("宝宝年龄")
                        Spacer()
                        Text("\(profile.ageInMonths) 个月")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("年龄分类")
                        Spacer()
 Text(profile.ageCategory.description)
                            .foregroundColor(.secondary)
                    }
                }
                Button("编辑宝宝信息") {
                    if let existing = userSettings.babyProfile {
                        babyName = existing.name
                        birthDate = existing.birthDate
                    }
                    showingEditProfile = true
                }
            }
            
            Section("关于") {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0")
                        .foregroundColor(.secondary)
                }
                
                Link("获取 OpenWeatherMap API Key", destination: URL(string: "https://openweathermap.org/api")!)
            }
        }
        .navigationTitle("设置")
        .sheet(isPresented: $showingEditProfile) {
            editProfileSheet
        }
    }
    
    private var editProfileSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("宝宝姓名（可选）", text: $babyName)
                    
                    DatePicker(
                        "出生日期",
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }
                
                Section {
                    let age = Calendar.current.dateComponents([.month], from: birthDate, to: Date()).month ?? 0
                    HStack {
                        Text("当前年龄")
                        Spacer()
                        Text("\(age) 个月")
                            .foregroundColor(.secondary)
                    }
                    
                    let category = BabyProfile(birthDate: birthDate).ageCategory
                    HStack {
                        Text("风险敏感度")
                        Spacer()
                        Text(category.description)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("编辑宝宝信息")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingEditProfile = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let profile = BabyProfile(birthDate: birthDate, name: babyName)
                        userSettings.saveBabyProfile(profile)
                        showingEditProfile = false
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SettingsView()
                .environmentObject(UserSettings.shared)
        }
    }
}
