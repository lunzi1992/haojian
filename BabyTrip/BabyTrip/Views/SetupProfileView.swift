//
//  SetupProfileView.swift
//  BabyTrip
//
//  Created by BabyTrip Project
//

import SwiftUI
import BabyTripShared

struct SetupProfileView: View {
    @EnvironmentObject var userSettings: UserSettings
    @State private var babyName = ""
    @State private var birthDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("欢迎使用宝宝出行助手") {
                    Text("首先让我们了解一下宝宝的信息，这样我们才能为您提供准确的出行建议。")
                        .foregroundColor(.secondary)
                }
                
                Section("宝宝信息") {
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
                        Text("风险等级调整")
                        Spacer()
                        Text(category.description)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("完成设置") {
                        let profile = BabyProfile(birthDate: birthDate, name: babyName)
                        userSettings.saveBabyProfile(profile)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("欢迎")
        }
    }
}

struct SetupProfileView_Previews: PreviewProvider {
    static var previews: some View {
        SetupProfileView()
            .environmentObject(UserSettings.shared)
    }
}
