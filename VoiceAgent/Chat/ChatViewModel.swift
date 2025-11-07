//
//  ChatViewModel.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import Foundation
import AgoraRtcKit
import AgoraRtmKit

class ChatViewModel: NSObject, ObservableObject {
    let uid: Int
    let token: String
    let channel: String
    
    // MARK: - 业务状态
    @Published var isMicMuted: Bool = false
    @Published var showMicOptions: Bool = false
    
    // MARK: - UI 状态（用于控制展示）
    @Published var showChat: Bool = false
    @Published var initializationError: Error? = nil
    @Published var transcripts: [Transcript] = []
    
    private var rtcEngine: AgoraRtcEngineKit?
    private var rtmEngine: AgoraRtmClientKit?
    private var convoAIAPI: ConversationalAIAPI?

    init(uid: Int, token: String, channel: String) {
        self.uid = uid
        self.token = token
        self.channel = channel
        
        super.init()
        start()
    }
    
    func start() {
        Task {
            do {
                //1：启动rtm
                try await startRTM()
                
                //2：启动RTC
                try await startRTC()
                
                //3：启动ConvoAI组件
                try await startConvoAIAPI()
                
            } catch {
                await MainActor.run {
                    initializationError = error
                    print("初始化失败: \(error)")
                }
            }
        }
    }
    
    @MainActor
    func startRTC() async throws {
        //初始化rtc
        let rtcConfig = AgoraRtcEngineConfig()
        rtcConfig.appId = KeyCenter.AG_APP_ID
        rtcConfig.channelProfile = .liveBroadcasting
        rtcConfig.audioScenario = .aiClient
        let rtcEngine = AgoraRtcEngineKit.sharedEngine(with: rtcConfig, delegate: self)
        
        //设置rtc
        rtcEngine.enableVideo()
        rtcEngine.enableAudioVolumeIndication(100, smooth: 3, reportVad: false)

        let cameraConfig = AgoraCameraCapturerConfiguration()
        cameraConfig.cameraDirection = .rear
        rtcEngine.setCameraCapturerConfiguration(cameraConfig)
        
        rtcEngine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
        
        //加入频道
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true
        let result = rtcEngine.joinChannel(byToken: token, channelId: channel, uid: UInt(uid), mediaOptions: options)
        if result != 0 {
            throw NSError(domain: "ChatViewModel", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "加入 RTC 频道失败，错误码: \(result)"])
        }
        self.rtcEngine = rtcEngine
    }
    
    @MainActor
    func startRTM() async throws {
        //初始化rtm
        let rtmConfig = AgoraRtmClientConfig(appId: KeyCenter.AG_APP_ID, userId: "\(uid)")
        rtmConfig.areaCode = [.CN, .NA]
        rtmConfig.presenceTimeout = 30
        rtmConfig.heartbeatInterval = 10
        rtmConfig.useStringUserId = true
        let rtmClient = try AgoraRtmClientKit(rtmConfig, delegate: self)
        self.rtmEngine = rtmClient
        
        //登录rtm
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "self 被释放"]))
                return
            }
            self.rtmEngine?.login(self.token) { res, error in
                if let error = error {
                    continuation.resume(throwing: NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtm 登录失败: \(error.localizedDescription)"]))
                } else if let _ = res {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtm 登录失败"]))
                }
            }
        }
    }
    
    @MainActor
    func startConvoAIAPI() async throws {
        guard let rtcEngine = self.rtcEngine else {
            throw NSError(domain: "startConvoAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtc 为空"])
        }
        
        guard let rtmEngine = self.rtmEngine else {
            throw NSError(domain: "startConvoAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtm 为空"])
        }
        
        let config = ConversationalAIAPIConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words, enableLog: true)
        let convoAIAPI = ConversationalAIAPIImpl(config: config)
        convoAIAPI.addHandler(handler: self)
        convoAIAPI.subscribeMessage(channelName: channel) { err in
            if let error = err {
                print("[subscribeMessage] <<<< error: \(error.message)")
            }
        }
        
        self.convoAIAPI = convoAIAPI
    }
    
    // MARK: - 业务方法
    func toggleMicrophone() {
        isMicMuted.toggle()
        rtcEngine?.adjustRecordingSignalVolume(isMicMuted ? 0 : 100)
    }
    
    func endCall() {
        // 结束通话：离开频道、清理资源等
        self.rtcEngine?.leaveChannel()
        AgoraRtcEngineKit.destroy()
        self.rtcEngine = nil
        
        self.rtmEngine?.logout()
        self.rtmEngine?.destroy()
        self.rtmEngine = nil
        
        self.convoAIAPI?.destroy()
    }
}

//RTC 回调
extension ChatViewModel: AgoraRtcEngineDelegate {
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("[RTC Call Back] didJoinedOfUid uid: \(uid)")
    }
    
    public func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("[RTC Call Back] didOfflineOfUid uid: \(uid)")
    }
}

//RTM 回调
extension ChatViewModel: AgoraRtmClientDelegate {
    public func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceiveLinkStateEvent event: AgoraRtmLinkStateEvent) {
        print("<<< [rtmKit:didReceiveLinkStateEvent]")
        switch event.currentState {
        case .connected:
            print("RTM connected successfully")
        case .disconnected:
            print("RTM disconnected")
        case .failed:
            print("RTM connection failed, need to re-login")
        default:
            break
        }
    }
}

//ConvoAIAPI 回调
extension ChatViewModel: ConversationalAIAPIEventHandler {
    public func onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {
        print("onAgentVoiceprintStateChanged: \(event)")
    }
    
    public func onMessageError(agentUserId: String, error: MessageError) {
        print("onMessageError: \(error)")
    }
    
    public func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
        print("onMessageReceiptUpdated: \(messageReceipt)")
    }
    
    public func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        print("onAgentStateChanged: \(event)")
    }
    
    public func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
        print("<<< [onAgentInterrupted]")
    }
    
    public func onAgentMetrics(agentUserId: String, metrics: Metric) {
        print("<<< [onAgentMetrics] metrics: \(metrics)")
    }
    
    public func onAgentError(agentUserId: String, error: ModuleError) {
        print("<<< [onAgentError] error: \(error)")
    }
    
    public func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 使用 turnId + type + userId 作为唯一标识，避免用户和 AI 的字幕互相覆盖
            if let index = self.transcripts.firstIndex(where: { 
                $0.turnId == transcript.turnId && 
                $0.type.rawValue == transcript.type.rawValue &&
                $0.userId == transcript.userId
            }) {
                // 更新现有字幕
                self.transcripts[index] = transcript
            } else {
                // 添加新字幕
                self.transcripts.append(transcript)
            }
        }
    }
    
    public func onDebugLog(log: String) {
        print(log)
    }
}

