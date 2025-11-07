//
//  EntranceViewModel.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import Foundation
import SwiftUI

struct ChatNavigationData: Identifiable, Hashable {
    var id = UUID()
    
    let uid: Int
    let token: String
    let channel: String
}

class EntranceViewModel: ObservableObject {
    @Published var navigationData: ChatNavigationData? = nil
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    let uid = Int.random(in: 1000...9999999)
    
    /// 从 EnvConfig 获取频道名称
    private var channelName: String {
        return EnvConfig.channel
    }

    func call() {
        // 防止重复请求
        guard !isLoading else { return }
        
        // 验证配置
        guard !EnvConfig.appId.isEmpty else {
            errorMessage = "请在 .env.xcconfig 配置文件中填写正确的 APPID"
            showError = true
            return
        }
        
        guard !channelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "请在 .env.xcconfig 配置文件中填写正确的 CHANNEL"
            showError = true
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let params = [
            "appCertificate": EnvConfig.appSecret,
            "appId": EnvConfig.appId,
            "channelName": channelName,
            "expire": 86400,
            "src": "iOS",
            "ts": 0,
            "types": [AgoraTokenType.rtc, AgoraTokenType.rtm].map { NSNumber(value: $0.rawValue) },
            "uid": "\(uid)"
        ] as [String: Any]
        
        let url = "https://service.apprtc.cn/toolbox/v2/token/generate"
        
        NetworkManager.shared.postRequest(urlString: url, params: params) { [weak self] response in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                guard let data = response["data"] as? [String: String],
                      let token = data["token"] else {
                    self.errorMessage = "获取 token 失败，请重试"
                    self.showError = true
                    return
                }
                
                self.navigationData = ChatNavigationData(uid: self.uid, token: token, channel: self.channelName)
            }
        } failure: { [weak self] error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "网络请求失败: \(error)"
                self.showError = true
            }
        }
    }
}
