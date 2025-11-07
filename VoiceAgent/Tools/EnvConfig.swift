//
//  EnvConfig.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/3.
//

import Foundation

class EnvConfig {
    private static var configCache: [String: String]?
    
    /// 从 .env.xcconfig 文件读取配置
    private static func loadConfig() -> [String: String] {
        if let cache = configCache {
            return cache
        }
        
        var config: [String: String] = [:]
        var configPath: String?
        
        // 方式1: 从 Bundle 中查找（如果文件被添加到项目中）
        if let bundlePath = Bundle.main.path(forResource: ".env", ofType: "xcconfig") {
            configPath = bundlePath
        } else if let bundlePath = Bundle.main.path(forResource: "env", ofType: "xcconfig") {
            configPath = bundlePath
        } else {
            // 方式2: 尝试从主 Bundle 的资源路径查找
            if let resourcePath = Bundle.main.resourcePath {
                let path = (resourcePath as NSString).appendingPathComponent(".env.xcconfig")
                if FileManager.default.fileExists(atPath: path) {
                    configPath = path
                }
            }
            
            // 方式3: 尝试从可执行文件所在目录查找（开发环境）
            if configPath == nil, let executablePath = Bundle.main.executablePath {
                let executableDir = (executablePath as NSString).deletingLastPathComponent
                let path = (executableDir as NSString).appendingPathComponent(".env.xcconfig")
                if FileManager.default.fileExists(atPath: path) {
                    configPath = path
                }
            }
        }
        
        guard let path = configPath, FileManager.default.fileExists(atPath: path) else {
            print("⚠️ 警告: 未找到 .env.xcconfig 文件，请确保文件已添加到项目中")
            configCache = config
            return config
        }
        
        config = parseConfigFile(at: path)
        configCache = config
        return config
    }
    
    /// 解析 xcconfig 格式的配置文件
    private static func parseConfigFile(at path: String) -> [String: String] {
        var config: [String: String] = [:]
        
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("⚠️ 警告: 无法读取配置文件: \(path)")
            return config
        }
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            // 移除注释和空白行
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("//") {
                continue
            }
            
            // 解析 KEY="VALUE" 或 KEY=VALUE 格式
            if let equalIndex = trimmedLine.firstIndex(of: "=") {
                let key = String(trimmedLine[..<equalIndex]).trimmingCharacters(in: .whitespaces)
                var value = String(trimmedLine[trimmedLine.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
                
                // 移除引号
                if value.hasPrefix("\"") && value.hasSuffix("\"") {
                    value = String(value.dropFirst().dropLast())
                }
                
                if !key.isEmpty {
                    config[key] = value
                }
            }
        }
        
        return config
    }
    
    /// 获取配置值
    /// - Parameter key: 配置键名
    /// - Returns: 配置值，如果不存在则返回空字符串
    static func get(_ key: String) -> String {
        let config = loadConfig()
        return config[key] ?? ""
    }
    
    /// 获取配置值（带默认值）
    /// - Parameters:
    ///   - key: 配置键名
    ///   - defaultValue: 默认值
    /// - Returns: 配置值，如果不存在则返回默认值
    static func get(_ key: String, defaultValue: String) -> String {
        let value = get(key)
        return value.isEmpty ? defaultValue : value
    }
    
    /// 清除缓存，强制重新加载配置
    static func reload() {
        configCache = nil
    }
    
    // MARK: - 便捷访问属性
    
    /// App ID
    static var appId: String {
        return get("APPID")
    }
    
    /// App Secret
    static var appSecret: String {
        return get("APPSECRET")
    }
    
    /// Channel
    static var channel: String {
        return get("CHANNEL")
    }
}

