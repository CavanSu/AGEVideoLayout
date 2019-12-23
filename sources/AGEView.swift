//
//  AGEView.swift
//  AGE
//
//  Created by CavanSu on 2019/9/24.
//  Copyright © 2019 CavanSu. All rights reserved.
//

#if os(iOS)
import UIKit
#else
import Cocoa
#endif

#if os(iOS)
public typealias AGEView = UIView
public typealias AGEColor = UIColor
public typealias AGESize = CGSize
public typealias AGEScroll = UIScrollView
public typealias AGERect = CGRect
#else
public typealias AGEView = NSView
public typealias AGEColor = NSColor
public typealias AGESize = NSSize
public typealias AGEScroll = NSScrollView
public typealias AGERect = NSRect
#endif

public extension AGEView {
    #if os(macOS)
    var backgroundColor: AGEColor {
        set {
            if self.layer == nil {
                self.wantsLayer = true
            }
            
            self.layer?.backgroundColor = newValue.cgColor
        }
        
        get {
            var color: AGEColor?
            if let layerColor = self.layer?.backgroundColor {
                color = AGEColor(cgColor: layerColor)
            }
            
            if let value = color {
                return value
            } else {
                return AGEColor.clear
            }
        }
    }
    #endif
}

extension AGEView {
    #if os(macOS)
    func layoutIfNeeded() {
        self.layoutSubtreeIfNeeded()
    }
    #endif
}

// MARK: - AGEScrollViewDelegate, AGELayoutViewDataSource
#if os(iOS)
typealias AGEScrollViewDelegate = UIScrollViewDelegate
#else
protocol AGEScrollViewDelegate: NSObjectProtocol {
    func scrollViewDidScroll(_ scrollView: AGELayoutView)
}
#endif

protocol AGELayoutViewDelegate: AGEScrollViewDelegate {
    func layoutView(_ layoutView: AGELayoutView, itemViewWillDisplay index: Int)
    func layoutView(_ layoutView: AGELayoutView, itemViewDidHidden index: Int)
}

protocol AGELayoutViewDataSource: NSObjectProtocol {
    func layoutViewNeedItemViews(_ layoutView: AGELayoutView) -> [AGEView]?
    func layoutViewNeedLayout(_ layoutView: AGELayoutView) -> AGEVideoLayout?
}

class AGELayoutView: AGEScroll {

    fileprivate struct ItemViewsTag {
        var isDisplay: Bool = false
    }
    
    fileprivate var lastContentOffset = CGPoint.zero
    fileprivate var contentViewBoundsObserver: Any?
    fileprivate var needResetItemViewsTag: Bool = true
    fileprivate var itemViewsTagList = [ItemViewsTag]()
    
    weak var ageDelegate: AGELayoutViewDelegate?
    weak var dataSource: AGELayoutViewDataSource?
    var runloopObserver: CFRunLoopObserver?
    var level: Int = 0
    
    #if os(macOS)
    var contentOffset: CGPoint {
        set {
            guard let documentView = documentView,
                let layout = dataSource?.layoutViewNeedLayout(self),
                layout.scrollType.isScroll else {
                return
            }
            
            var offset: CGPoint

            if layout.scrollType.isVertical {
                let y = abs((documentView.bounds.height - self.bounds.height) - newValue.y)
                offset = CGPoint(x: 0, y: y)
            } else {
                offset = newValue
            }
            
            documentView.scroll(offset)
        }
        get {
            guard let documentView = documentView,
                let layout = dataSource?.layoutViewNeedLayout(self),
                layout.scrollType.isScroll else {
                return CGPoint.zero
            }
            
            var contentOffset: CGPoint
            
            if layout.scrollType.isVertical {
                let y = abs(documentVisibleRect.origin.y - (documentView.bounds.height - self.bounds.height))
                contentOffset = CGPoint(x: 0, y: y)
            } else {
                contentOffset = documentVisibleRect.origin
            }
            
            return contentOffset
        }
    }
    #endif
    
    override init(frame frameRect: AGERect) {
        super.init(frame: frameRect)
        doInitSettings()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        doInitSettings()
    }
    
    init() {
        super.init(frame: AGERect(x: 0, y: 0, width: 0, height: 0))
        doInitSettings()
    }
    
    init(level: Int, dataSource: AGELayoutViewDataSource) {
        super.init(frame: AGERect(x: 0, y: 0, width: 0, height: 0))
        self.level = level
        self.dataSource = dataSource
        doInitSettings()
    }
    
    deinit {
        #if os(macOS)
        if let contentViewBoundsObserver = contentViewBoundsObserver {
            NotificationCenter.default.removeObserver(contentViewBoundsObserver)
            self.contentViewBoundsObserver = nil
        }
        #endif
        
        removeRunLoopObserver()
    }
    
    #if os(macOS)
    func scrollToTop() {
        self.contentOffset = CGPoint.zero
    }
    
    func scrollToLastContentOffset() {
        self.contentOffset = lastContentOffset
    }
    #endif
}

extension AGELayoutView {
    func update(itemViews layout: AGEVideoLayout) -> [NSLayoutConstraint]? {
        guard let itemViews = dataSource?.layoutViewNeedItemViews(self) else {
            return nil
        }
        
        // If need add runloop observer
        switch layout.scrollType {
        case .static:
            removeRunLoopObserver()
        case .scroll:
            addRunLoopObserver()
        }
        
        let number = itemViews.count
        let itemSize = layout.itemSize
        var itemsConstraints = [NSLayoutConstraint]()
        
        var rankCount: Int
        var rowCount: Int
        var width: CGFloat
        var height: CGFloat
        
        #if os(iOS)
        self.isScrollEnabled = layout.scrollType.isScroll
        //        layoutView.isPagingEnabled = layout.type.isScroll
        #endif
        
        var interitemSpacing: CGFloat = 0
        var lineSpacing: CGFloat = 0
        
        switch layout.scrollType {
        case .static:
            
            switch itemSize {
            case .scale:
                if itemSize.width > 0.5 {
                    rankCount = 1
                } else  {
                    rankCount = Int(1.0 / itemSize.width)
                }
                
                if itemSize.height > 0.5 {
                    rowCount = 1
                } else  {
                    rowCount = Int(1.0 / itemSize.height)
                }
                
                let iSpacing = layout.interitemSpacing / self.bounds.width
                let interitemSpacingScale = (iSpacing >= 1 ? 0 : iSpacing)
                
                let lSpacing = layout.lineSpacing / self.bounds.height
                let lineSpacingScale = (lSpacing >= 1 ? 0 : lSpacing)
                
                width = (1.0 - (interitemSpacingScale * CGFloat(rankCount - 1))) / CGFloat(rankCount)
                height = (1.0 - (lineSpacingScale * CGFloat(rowCount - 1))) / CGFloat(rowCount)
            case .constant:
                if itemSize.width > self.bounds.width * 0.5 {
                    rankCount = 1
                } else {
                    rankCount = Int(self.bounds.width / itemSize.width)
                }
                
                if itemSize.height > self.bounds.height * 0.5 {
                    rowCount = 1
                } else  {
                    rowCount = Int(self.bounds.height / itemSize.height)
                }
                
                width = itemSize.width
                height = itemSize.height
            }
            
            interitemSpacing = layout.interitemSpacing
            lineSpacing = layout.lineSpacing
            
            #if os(macOS)
            if let view = self.documentView {
                let constrains = AGEVideoConstraints.add(for: view,
                                                         on: self,
                                                         startPoint: CGPoint.zero,
                                                         whSize: .scale(CGSize(width: 1.0, height: 1.0)),
                                                         needAddSubView: false)
                itemsConstraints.append(contentsOf: constrains)
            }
            #endif
        case .scroll(let direction):
            switch direction {
            case .horizontal:
                
                switch layout.itemSize {
                case .scale:
                    let contentWidth = CGFloat(number) * self.bounds.width * layout.size.width * layout.itemSize.width + CGFloat(number - 1) * layout.interitemSpacing
                    #if os(iOS)
                    self.contentSize = AGESize(width: contentWidth, height: 0)
                    #else
                    let view = AGEView(frame: NSRect(x: 0, y: 0, width: contentWidth, height: self.bounds.height))
                    self.documentView = view
                    #endif
                    
                    height = 1.0
                    #if os(iOS)
                    width = layout.itemSize.width
                    #else
                    width = (self.bounds.width * layout.itemSize.width) / contentWidth
                    #endif
                case .constant:
                    let contentWidth = CGFloat(number) * layout.itemSize.width + CGFloat(number - 1) * layout.interitemSpacing
                    #if os(iOS)
                    self.contentSize = AGESize(width: contentWidth, height: 0)
                    #else
                    let viewWidth = contentWidth < self.bounds.width ? self.bounds.width : contentWidth
                    let view = AGEView(frame: NSRect(x: 0, y: 0, width: viewWidth, height: self.bounds.height))
                    self.documentView = view
                    #endif
                    
                    height = self.bounds.height
                    #if os(iOS)
                    width = layout.itemSize.width
                    #else
                    width = layout.itemSize.width
                    #endif
                }
                
                rowCount = 1
                rankCount = number
                interitemSpacing = layout.interitemSpacing
            case .vertical:
                
                switch layout.itemSize {
                case .scale:
                    let contentHeight = CGFloat(number) * self.bounds.height * layout.size.height * layout.itemSize.height + CGFloat(number - 1) * layout.lineSpacing
                    #if os(iOS)
                    self.contentSize = AGESize(width: 0, height: contentHeight)
                    #else
                    let view = AGEView(frame: NSRect(x: 0, y: 0, width: self.bounds.width, height: contentHeight))
                    self.documentView = view
                    #endif
                    rankCount = 1
                    rowCount = number
                    width = 1.0
                    #if os(iOS)
                    height = layout.itemSize.height
                    #else
                    height = (self.bounds.height * layout.itemSize.height) / contentHeight
                    #endif
                case .constant:
                    let contentHeight = CGFloat(number) * layout.itemSize.height + CGFloat(number - 1) * layout.lineSpacing
                    #if os(iOS)
                    self.contentSize = AGESize(width: 0, height: contentHeight)
                    #else
                    let viewHeight = contentHeight < self.bounds.height ? self.bounds.height : contentHeight
                    let view = AGEView(frame: NSRect(x: 0, y: 0, width: self.bounds.width, height: viewHeight))
                    
                    self.documentView = view
                    #endif
                    rankCount = 1
                    rowCount = number
                    width = self.bounds.width
                    #if os(iOS)
                    height = layout.itemSize.height
                    #else
                    height = layout.itemSize.height
                    #endif
                }
                
                lineSpacing = layout.lineSpacing
            }
        }
        
        var superView: AGEView
        #if os(iOS)
        superView = self
        #else
        superView = self.documentView!
        superView.wantsLayer = true
        superView.layer?.backgroundColor = NSColor.clear.cgColor
        #endif
        
        var whSize: AGEVideoLayout.ConstraintsType
        switch layout.itemSize {
        case .scale:
            whSize = .scale(CGSize(width: width, height: height))
        case .constant:
            whSize = .constant(CGSize(width: width, height: height))
        }
        
        let rankRow = AGERankRow(ranks: rankCount, rows: rowCount)
        let constraints = AGEVideoConstraints.add(for: itemViews,
                                                  on: superView,
                                                  rankRow: rankRow,
                                                  whSize: whSize,
                                                  interitemSpacing: interitemSpacing,
                                                  lineSpacing: lineSpacing)
        itemsConstraints.append(contentsOf: constraints)
        
        // Dirty tag of ItemViews
        needResetItemViewsTag = true
        
        return itemsConstraints
    }
    
    func removeAllItemViews() {
        #if os(iOS)
        for subView in self.subviews {
            subView.removeFromSuperview()
        }
        #else
        guard let view = self.documentView else {
            return
        }
        
        for subView in view.subviews {
            subView.removeFromSuperview()
        }
        #endif
    }
}

private extension AGELayoutView {
    func doInitSettings() {
        translatesAutoresizingMaskIntoConstraints = false
        #if os(iOS)
        alwaysBounceHorizontal = false
        showsHorizontalScrollIndicator = false
        alwaysBounceVertical = false
        showsVerticalScrollIndicator = false
        #else
        self.wantsLayer = true
        self.layer?.backgroundColor = NSColor.clear.cgColor
        self.drawsBackground = false // before set background color
        
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 0, height: 0))
        self.documentView = view
        verticalScrollElasticity = .automatic
        horizontalScrollElasticity = .automatic
        
        contentView.postsBoundsChangedNotifications = true
        guard contentViewBoundsObserver == nil else {
            return
        }
        let center = NotificationCenter.default
        contentViewBoundsObserver = center.addObserver(forName: NSView.boundsDidChangeNotification,
                                                       object: contentView,
                                                       queue: nil) { [weak self] (notify) in
                                                        if let strongSelf = self {
                                                            strongSelf.ageDelegate?.scrollViewDidScroll(strongSelf)
                                                        }
        }
        #endif
    }
    
    func addRunLoopObserver() {
        guard runloopObserver == nil else {
            return
        }
        
        let allocator = CFAllocatorGetDefault().takeRetainedValue()
        
        let observer = CFRunLoopObserverCreateWithHandler(allocator, CFRunLoopActivity.beforeWaiting.rawValue,
                                                          true,
                                                          2000010) { [weak self] (observer, activity) in
                                                            
                                                            guard let strongSelf = self else {
                                                                return
                                                            }
                                                            
                                                            guard let itemViews = strongSelf.dataSource?.layoutViewNeedItemViews(strongSelf) else {
                                                                    return
                                                            }
                                                            
                                                            guard let layout = strongSelf.dataSource?.layoutViewNeedLayout(strongSelf) else {
                                                                return
                                                            }
                                                            
                                                            // Reset item views tag, and noticate delegate that item view hidden status
                                                            if strongSelf.needResetItemViewsTag {
                                                                switch layout.scrollType {
                                                                case .scroll(let direction):
                                                                    strongSelf.resetItemViewsTag(itemViews: itemViews, layout: layout, direction: direction)
                                                                case .static:
                                                                    break
                                                                }
                                                                return
                                                            }
                                                            
                                                            // During dragging, item view hidden status
                                                            strongSelf.duringLayoutViewBeDragging(itemViews: itemViews, layout: layout)
        }
        
        CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, CFRunLoopMode.commonModes)
        runloopObserver = observer
    }
    
    func removeRunLoopObserver() {
        if let observer = self.runloopObserver {
            CFRunLoopRemoveObserver(CFRunLoopGetMain(),
                                    observer, CFRunLoopMode.commonModes)
            
            self.runloopObserver = nil
            self.lastContentOffset = CGPoint.zero
        }
    }
}

private extension AGELayoutView {
    func resetItemViewsTag(itemViews: [AGEView], layout: AGEVideoLayout, direction: AGEVideoLayout.Direction) {
        guard let itemView = itemViews.first else {
            return
        }
        
        itemViewsTagList.removeAll()
        needResetItemViewsTag = false
        
        switch direction {
        case .vertical:
            let itemSpace = itemView.bounds.height + layout.lineSpacing
            let rangBottom = Int(ceil((contentOffset.y + bounds.height) / itemSpace)) - 1
            var rangTop = Int(ceil(contentOffset.y / itemSpace)) - 1
            rangTop = rangTop >= 0 ? rangTop : 0
            
            for i in 0..<itemViews.count {
                var tag = ItemViewsTag()
                
                if i >= rangTop && i <= rangBottom {
                    tag.isDisplay = true
                    ageDelegate?.layoutView(self, itemViewWillDisplay: i)
                } else {
                    tag.isDisplay = false
                    ageDelegate?.layoutView(self, itemViewDidHidden: i)
                }
                
                itemViewsTagList.append(tag)
            }
            
        case .horizontal:
            let itemSpace = itemView.bounds.width + layout.interitemSpacing
            let rangBottom = Int(ceil((contentOffset.x + self.bounds.width) / itemSpace)) - 1
            var rangTop = Int(ceil(contentOffset.x / itemSpace)) - 1
            rangTop = rangTop >= 0 ? rangTop : 0
            
            for i in 0..<itemViews.count {
                var tag = ItemViewsTag()
                
                if i >= rangTop && i <= rangBottom {
                    tag.isDisplay = true
                    ageDelegate?.layoutView(self, itemViewWillDisplay: i)
                } else {
                    tag.isDisplay = false
                    ageDelegate?.layoutView(self, itemViewDidHidden: i)
                }
                
                itemViewsTagList.append(tag)
            }
        }
    }
    
    func duringLayoutViewBeDragging(itemViews: [AGEView], layout: AGEVideoLayout) {
        guard let itemView = itemViews.first else {
                return
        }
        
        #if os(iOS)
        let maxX = (contentSize.width - bounds.width) > 0 ? contentSize.width - bounds.width : 0
        let maxY = (contentSize.height - bounds.height) > 0 ? contentSize.height - bounds.height : 0
        #else
        guard let document = documentView else {
            return
        }
        
        let maxX = (document.bounds.width - bounds.width) > 0 ? document.bounds.width - bounds.width : 0
        let maxY = (document.bounds.height - bounds.height) > 0 ? document.bounds.height - bounds.height : 0
        #endif
        
        guard contentOffset.x >= 0,
            contentOffset.y >= 0,
            contentOffset.x <= maxX,
            contentOffset.y <= maxY else {
            return
        }
                                                                    
        let direction = lastContentOffset.compare(new: contentOffset)
        
        func isDisplay(_ isDisplay: Bool, with index: Int) {
            var tag = itemViewsTagList[index]
            // Will display
            if isDisplay {
                if !tag.isDisplay {
                    ageDelegate?.layoutView(self, itemViewWillDisplay: index)
                    tag.isDisplay = true
                    itemViewsTagList[index] = tag
                }
            // Did Hidden
            } else {
                if tag.isDisplay {
                    ageDelegate?.layoutView(self, itemViewDidHidden: index)
                    tag.isDisplay = false
                    itemViewsTagList[index] = tag
                }
            }
        }
        
        switch direction {
        case .topToBottom:
            // will display
            let itemSpace = itemView.bounds.height + layout.lineSpacing
            let displayIndex = Int(ceil((contentOffset.y + bounds.height) / itemSpace)) - 1
            if displayIndex >= 0 {
                isDisplay(true, with: displayIndex)
            }
            
            // did hidden
            let hiddenIndex = Int(contentOffset.y / itemSpace) - 1
            if hiddenIndex >= 0 {
                isDisplay(false, with: hiddenIndex)
            }
        case .bottomToTop:
            // will display
            let itemSpace = itemView.bounds.height + layout.lineSpacing
            let displayIndex = Int(ceil(contentOffset.y / itemSpace)) - 1
            if displayIndex >= 0 {
                isDisplay(true, with: displayIndex)
            }
            
            // did hidden
            let hiddenIndex = Int((contentOffset.y + bounds.height) / itemSpace) + 1
            if hiddenIndex <= itemViews.count - 1 {
                isDisplay(false, with: hiddenIndex)
            }
        case .leftToRight:
            // will display
            let itemSpace = itemView.bounds.width + layout.interitemSpacing
            let displayIndex = Int(ceil((contentOffset.x + bounds.width) / itemSpace)) - 1
            if displayIndex >= 0 {
                isDisplay(true, with: displayIndex)
            }
            
            // did hidden
            let hiddenIndex = Int(contentOffset.x / itemSpace) - 1
            if hiddenIndex >= 0 {
                 isDisplay(false, with: hiddenIndex)
            }
        case .rightToLeft:
            // will display
            let itemSpace = itemView.bounds.width + layout.interitemSpacing
            let displayIndex = Int(ceil(contentOffset.x / itemSpace)) - 1
            if displayIndex >= 0 {
                isDisplay(true, with: displayIndex)
            }
            
            // did hidden
            let hiddenIndex = Int((contentOffset.x + bounds.width) / itemSpace) + 1
            if hiddenIndex <= itemViews.count - 1 {
                isDisplay(false, with: hiddenIndex)
            }
        case .stop:
            break
        }
        
        lastContentOffset = contentOffset
    }
}

fileprivate extension CGPoint {
    enum ScrollDirection {
        case leftToRight, rightToLeft, topToBottom, bottomToTop, stop
        
        var isStop: Bool {
            switch self {
            case .stop: return true
            default:    return false
            }
        }
        
        var description: String {
            switch self {
            case .leftToRight: return "left to right"
            case .rightToLeft: return "right to left"
            case .topToBottom: return "top to bottom"
            case .bottomToTop: return "bottom to top"
            case .stop:        return "stop"
            }
        }
    }
    
    func compare(new: CGPoint) -> ScrollDirection {
        guard self != new else {
            return .stop
        }
        
        if self.x == 0, new.x == 0 {
            return self.y > new.y ? .bottomToTop : .topToBottom
        }
        
        if self.y == 0, new.y == 0 {
            return self.x > new.x ? .rightToLeft : .leftToRight
        }
        
        return .stop
    }
    
    static func !=(left:CGPoint, right: CGPoint) -> Bool {
        if left.x == right.x, left.y == right.y {
            return false
        } else {
            return true
        }
    }
}
