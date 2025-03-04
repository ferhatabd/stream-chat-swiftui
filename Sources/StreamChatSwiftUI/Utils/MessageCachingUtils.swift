//
// Copyright © 2024 Stream.io Inc. All rights reserved.
//

import Foundation
import StreamChat
import UIKit

/// Caches messages related data to avoid accessing the database.
/// Cleared on chat channel view dismiss or memory warning.
public class MessageCachingUtils {

    private var messageAuthorMapping = [String: String]()
    private var messageAuthors = [String: UserDisplayInfo]()
    private var checkedMessageIds = Set<String>()
    private var quotedMessageMapping = [String: ChatMessage]()

    public var scrollOffset: CGFloat = 0
    
    public init(messageAuthorMapping: [String : String] = [String: String](), messageAuthors: [String : UserDisplayInfo] = [String: UserDisplayInfo](), checkedMessageIds: Set<String> = Set<String>(), quotedMessageMapping: [String : ChatMessage] = [String: ChatMessage](), scrollOffset: CGFloat = 0, messageThreadShown: Bool = false, jumpToReplyId: String? = nil) {
        self.messageAuthorMapping = messageAuthorMapping
        self.messageAuthors = messageAuthors
        self.checkedMessageIds = checkedMessageIds
        self.quotedMessageMapping = quotedMessageMapping
        self.scrollOffset = scrollOffset
        self.messageThreadShown = messageThreadShown
        self.jumpToReplyId = jumpToReplyId
    }
    
    var messageThreadShown = false {
        didSet {
            if !messageThreadShown {
                jumpToReplyId = nil
            }
        }
    }
    
    var jumpToReplyId: String?

    func authorId(for message: ChatMessage) -> String {
        if let userDisplayInfo = userDisplayInfo(for: message) {
            return userDisplayInfo.id
        }

        let userDisplayInfo = saveUserDisplayInfo(for: message)
        return userDisplayInfo.id
    }

    func authorName(for message: ChatMessage) -> String {
        if let userDisplayInfo = userDisplayInfo(for: message) {
            return userDisplayInfo.name
        }

        let userDisplayInfo = saveUserDisplayInfo(for: message)
        return userDisplayInfo.name
    }

    func authorImageURL(for message: ChatMessage) -> URL? {
        if let userDisplayInfo = userDisplayInfo(for: message) {
            return userDisplayInfo.imageURL
        }

        let userDisplayInfo = saveUserDisplayInfo(for: message)
        return userDisplayInfo.imageURL
    }

    func authorInfo(from message: ChatMessage) -> UserDisplayInfo {
        if let userDisplayInfo = userDisplayInfo(for: message) {
            return userDisplayInfo
        }

        let userDisplayInfo = saveUserDisplayInfo(for: message)
        return userDisplayInfo
    }

    func quotedMessage(for message: ChatMessage) -> ChatMessage? {
        if StreamRuntimeCheck._isDatabaseObserverItemReusingEnabled {
            return message.quotedMessage
        }
        
        if checkedMessageIds.contains(message.id) {
            return nil
        }

        if let quoted = quotedMessageMapping[message.id] {
            return quoted
        }

        let quoted = message.quotedMessage
        if quoted == nil {
            checkedMessageIds.insert(message.id)
        } else {
            quotedMessageMapping[message.id] = quoted
        }

        return quoted
    }

    func userDisplayInfo(with id: String) -> UserDisplayInfo? {
        for userInfo in messageAuthors.values {
            if userInfo.id == id {
                return userInfo
            }
        }
        return nil
    }

    func clearCache() {
        log.debug("Clearing cached message data")
        scrollOffset = 0
        messageThreadShown = false
        messageAuthorMapping = [String: String]()
        messageAuthors = [String: UserDisplayInfo]()
        checkedMessageIds = Set<String>()
        quotedMessageMapping = [String: ChatMessage]()
    }

    // MARK: - private

    private func userDisplayInfo(for message: ChatMessage) -> UserDisplayInfo? {
        if StreamRuntimeCheck._isDatabaseObserverItemReusingEnabled {
            let user = message.author
            return UserDisplayInfo(
                id: user.id,
                name: user.name ?? user.id,
                imageURL: user.imageURL,
                role: user.userRole
            )
        }
        
        if let userId = messageAuthorMapping[message.id],
           let userDisplayInfo = messageAuthors[userId] {
            return userDisplayInfo
        } else {
            return nil
        }
    }

    private func saveUserDisplayInfo(for message: ChatMessage) -> UserDisplayInfo {
        let user = message.author
        let userDisplayInfo = UserDisplayInfo(
            id: user.id,
            name: user.name ?? user.id,
            imageURL: user.imageURL,
            role: user.userRole
        )
        messageAuthorMapping[message.id] = user.id
        messageAuthors[user.id] = userDisplayInfo

        return userDisplayInfo
    }
}

/// Contains display information for the user.
public struct UserDisplayInfo {
    public let id: String
    public let name: String
    public let imageURL: URL?
    public let role: UserRole?

    public init(id: String, name: String, imageURL: URL?, role: UserRole? = nil) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.role = role
    }
}

extension ChatMessage {

    public var authorDisplayInfo: UserDisplayInfo {
        let cachingUtils = InjectedValues[\.utils].messageCachingUtils
        return cachingUtils.authorInfo(from: self)
    }

    public func userDisplayInfo(from id: String) -> UserDisplayInfo? {
        let cachingUtils = InjectedValues[\.utils].messageCachingUtils
        return cachingUtils.userDisplayInfo(with: id)
    }
}
