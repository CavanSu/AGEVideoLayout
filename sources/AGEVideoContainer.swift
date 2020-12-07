//
//  AGEVideoContainer.swift
//  AGE
//
//  Created by CavanSu on 2019/7/23.
//  Copyright © 2019 CavanSu. All rights reserved.
//

#if os(iOS)
import UIKit
#else
import Cocoa
#endif

public protocol AGEVideoContainerDataSource: NSObjectProtocol {
    func container(_ container: AGEVideoContainer, numberOfItemsIn level: Int) -> Int
    func container(_ container: AGEVideoContainer, viewForItemAt index: AGEIndex) -> AGEView
}

public protocol AGEVideoContainerDelegate: NSObjectProtocol {
    func container(_ container: AGEVideoContainer, didSelected itemView: AGEView, index: AGEIndex)
    func container(_ container: AGEVideoContainer, itemWillDisplay index: AGEIndex)
    func container(_ container: AGEVideoContainer, itemDidHidden index: AGEIndex)
}

public extension AGEVideoContainerDelegate {
    func container(_ container: AGEVideoContainer, didSelected itemView: AGEView, index: AGEIndex) {}
    func container(_ container: AGEVideoContainer, itemWillDisplay index: AGEIndex) {}
    func container(_ container: AGEVideoContainer, itemDidHidden index: AGEIndex) {}
}

public class AGEVideoContainer: AGEView {
    public class AGELog: NSObject {
        static var currentNeedLog: LogType? = nil
        
        static var separator: String = "----------------"
        
        struct LogType: OptionSet {
            var rawValue: Int
                        
            static let all: LogType = {
                let value = (LogType.eventsTrain.rawValue
                + LogType.updateLayoutConstraints.rawValue
                + LogType.willHiddenItemView.rawValue)
                return LogType(rawValue:value)
            }()
            
            static let eventsTrain = LogType(rawValue: 1)
            static let updateLayoutConstraints = LogType(rawValue: 1 << 1)
            static let willHiddenItemView = LogType(rawValue: 1 << 2)
            
            var tag: String {
                if self == LogType.eventsTrain {
                    return "Events train"
                } else if self == LogType.updateLayoutConstraints {
                    return "Update Constraints"
                } else if self == LogType.willHiddenItemView {
                    return "Will Hidden Item View"
                } else {
                    return "All"
                }
            }
        }
        
        static func log(_ content: String, type: LogType) {
            guard let needLog = currentNeedLog else {
                return
            }
            
            func log(content: String, tag: String) {
                NSLog("AGELog - \(tag): \(content)")
            }
            
            if needLog == LogType.all {
                log(content: content, tag: needLog.tag)
                return
            }
            
            if needLog.contains(type) {
                log(content: content, tag: type.tag)
            }
        }
    }
    
    class AGELevelItem: NSObject {
        enum ViewType {
            case view(AGELayoutView)
            
            var view: AGELayoutView {
                switch self {
                case .view(let aView): return aView
                }
            }
        }
        
        var layout: AGEVideoLayout
        var viewType: ViewType
        var layoutConstraints: [NSLayoutConstraint]
        var itemsConstraints: [NSLayoutConstraint]?
        
        init(layout: AGEVideoLayout,
             viewType: ViewType,
             layoutConstraints: [NSLayoutConstraint],
             itemsConstraints: [NSLayoutConstraint]?) {
            
            self.layout = layout
            self.viewType = viewType
            self.layoutConstraints = layoutConstraints
            self.itemsConstraints = itemsConstraints
        }
    }
    
    public typealias ListCountBlock = ((_ level: Int) -> Int)?
    public typealias ListItemBlock = ((_ index: AGEIndex) -> AGEView)?
    public typealias ListRankRowBlock = ((_ level: Int) -> AGERankRow)?
    
    private lazy var levels = [Int: AGELevelItem]()
    private var eventsObserver = AGEEventsObserver()
    
    private var firstLayout = false
    
    private var listCount: ListCountBlock = nil
    private var listItem: ListItemBlock = nil
    
    private let animationTime: TimeInterval = 0.3
    
    public weak var dataSource: AGEVideoContainerDataSource?
    public weak var delegate: AGEVideoContainerDelegate?
    
    #if os(macOS)
    override open func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        addEventsObserver()
    }
    #else
    override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        addTapGesture()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addTapGesture()
    }
    
    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        addTapGesture()
    }
    #endif
}

public extension AGEVideoContainer {
    func reload(level: Int, animated: Bool = false) {
        guard let levelItem = levels[level] else {
            return
        }
        
        let layoutView = levelItem.viewType.view
        layoutView.removeAllItemViews()
        let itemsConstraints = layoutView.update(itemViews: levelItem.layout)
        
        if let olds = levelItem.itemsConstraints {
            privateRemoveConstraints(olds)
        }
        
        if let news = itemsConstraints {
            levelItem.itemsConstraints = itemsConstraints
            NSLayoutConstraint.activate(news)
        }
       
        #if os(macOS)
        if levelItem.layout.scrollType.isScroll {
            layoutView.scrollToLastContentOffset()
        }
        #endif
        
        if animated {
            #if os(iOS)
            AGEView.animate(withDuration: animationTime) { [weak self] in
                self?.layoutIfNeeded()
            }
            #else
            if #available(OSX 10.12, *) {
                NSAnimationContext.runAnimationGroup { [weak self] (context) in
                    guard let strongSelf = self else {
                        return
                    }
                    context.duration = strongSelf.animationTime
                    context.allowsImplicitAnimation = true
                    strongSelf.layoutIfNeeded()
                }
            }
            #endif
        }
    }
    
    func setLayouts(_ layouts: [AGEVideoLayout], animated: Bool = false) {
        guard layouts.count > 0 else {
            return
        }
        
        let sorted = layouts.sorted { (item1, item2) -> Bool in
            return item1.level < item2.level
        }
        
        if !firstLayout {
            self.firstLayout = true
            self.layoutIfNeeded()
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }
            
            for item in sorted {
                strongSelf.updateSingalLayout(item, animated: animated)
            }
        }
    }
    
    func removeAllLayouts() {
        let allLevels = levels.keys
        
        for level in allLevels {
            removeLayout(level: level)
        }
    }
    
    func removeLayout(level: Int) {
        guard let levelItem = levels[level] else {
           return
        }
        privateRemoveConstraints(levelItem.layoutConstraints)
        if let itemsConstraints = levelItem.itemsConstraints {
           privateRemoveConstraints(itemsConstraints)
        }
        let layoutView = levelItem.viewType.view
        layoutView.removeAllItemViews()
        layoutView.removeFromSuperview()
        levels.removeValue(forKey: level)
    }
    
    @discardableResult func listCount(_ block: ListCountBlock) -> AGEVideoContainer {
        self.listCount = block
        return self
    }
    
    @discardableResult func listItem(_ block: ListItemBlock) -> AGEVideoContainer {
        self.listItem = block
        return self
    }
}

private extension AGEVideoContainer {
    func setup(logLevel: AGELog.LogType) {
        AGEVideoContainer.AGELog.currentNeedLog = logLevel
    }
    
    func updateSingalLayout(_ layout: AGEVideoLayout, animated: Bool = false) {
        if let levelItem = levels[layout.level] {
            let oldLayout = levelItem.layout
            let result = oldLayout.isEqual(right: layout)
            
            switch result {
            case .yes: break
            case .no(let reasons):
                AGELog.log("reasons: \(reasons.description)", type: .updateLayoutConstraints)
                
                levelItem.layout = layout
                levels[layout.level] = levelItem
                
                let layoutView = levelItem.viewType.view
                
                var newConstraints = [NSLayoutConstraint]()
                
                // Reset ItemViews constraints
                if reasons.containsOneOf([.interitemSpacing,
                                          .lineSpacing,
                                          .itemSize,
                                          .scrollType]) {
                    
                    layoutView.removeAllItemViews()
                                        
                    if let olds = levelItem.itemsConstraints {
                        privateRemoveConstraints(olds)
                        AGELog.log("old itemsConstraints count: \(olds.count)", type: .updateLayoutConstraints)
                    }
                    
                    if let itemsConstraints = layoutView.update(itemViews: layout) {
                        AGELog.log("new itemsConstraints count: \(itemsConstraints.count)", type: .updateLayoutConstraints)
                        levelItem.itemsConstraints = itemsConstraints
                        newConstraints.append(contentsOf: itemsConstraints)
                    }
                }
                
                // Reset LayoutView constraints
                if reasons.containsOneOf([.startPoint,
                                          .size]) {
                    
                    let olds = levelItem.layoutConstraints
                    privateRemoveConstraints(olds)
                    
                    let layoutConstraints = updateLayoutViewConstraints(layoutView, layout: layout)
                    levelItem.layoutConstraints = layoutConstraints
                    
                    newConstraints.append(contentsOf: layoutConstraints)
                }
                
                NSLayoutConstraint.activate(newConstraints)
                
                // Reset layoutView contentOffset
                if !layout.scrollType.isScroll {
                    layoutView.contentOffset = CGPoint.zero
                }
                
                // Animation
                layoutAnimation(animated)
                
                levels[layout.level] = levelItem
            }
        } else {
            createSingalLayout(layout, animated: animated)
        }
    }
    
    func createSingalLayout(_ layout: AGEVideoLayout, animated: Bool = false) {
        // layoutView
        let layoutView = AGELayoutView(level: layout.level,
                                       dataSource: self)
        layoutView.ageDelegate = self
        
        let layoutConstraints = updateLayoutViewConstraints(layoutView, layout: layout)
        NSLayoutConstraint.activate(layoutConstraints)
        layoutView.layoutIfNeeded()

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else {
                return
            }

            // itemViews
            let itemsConstraints = layoutView.update(itemViews: layout)
            
            strongSelf.levels[layout.level] = AGELevelItem(layout: layout,
                                                           viewType: .view(layoutView),
                                                           layoutConstraints: layoutConstraints,
                                                           itemsConstraints: itemsConstraints)
            
            if let constraints = itemsConstraints {
                #if os(macOS)
                if layout.scrollType.isScroll {
                    layoutView.scrollToTop()
                }
                #endif
                
                NSLayoutConstraint.activate(constraints)
                strongSelf.layoutAnimation(animated)
            }
        }
    }
}

private extension AGEVideoContainer {
    func updateLayoutViewConstraints(_ view: AGEView, layout: AGEVideoLayout) -> [NSLayoutConstraint] {
        let startPoint = layout.startPoint
        let layoutConstraints = AGEVideoConstraints.add(for: view,
                                                        on: self,
                                                        startPoint: startPoint,
                                                        whSize: layout.size)
                
        return layoutConstraints
    }
    
    func layoutAnimation(_ animated: Bool) {
        if animated {
            #if os(iOS)
            AGEView.animate(withDuration: animationTime) { [weak self] in
                self?.layoutIfNeeded()
            }
            #else
            if #available(OSX 10.12, *) {
                NSAnimationContext.runAnimationGroup { [weak self] (context) in
                    guard let strongSelf = self else {
                        return
                    }
                    
                    context.duration = strongSelf.animationTime
                    context.allowsImplicitAnimation = true
                    strongSelf.layoutIfNeeded()
                }
            }
            #endif
        }
    }
}

private extension AGEVideoContainer {
    func numberOfList(_ level: Int) -> Int {
        var count: Int = 0
        if let listCount = self.listCount {
            count = listCount(level)
        } else if let number = dataSource?.container(self, numberOfItemsIn: level) {
            count = number
        }
        return count
    }
    
    func viewOfList(level: Int, item: Int) -> AGEView? {
        var itemView: AGEView?
        if let listItem = self.listItem {
            let index = AGEIndex(level: level, item: item)
            itemView = listItem(index)
        } else if let view = dataSource?.container(self, viewForItemAt: AGEIndex(level: level, item: item)) {
            itemView = view
        }
        return itemView
    }
    
    func viewsOfList(level: Int) -> [AGEView]? {
        let number = numberOfList(level)
        guard number > 0 else {
            return nil
        }
        
        var itemViews = [AGEView]()
        
        for index in 0..<number {
            if let view = viewOfList(level: level, item: index) {
                itemViews.append(view)
            }
        }
        
        return itemViews
    }
}

// MARK: - Events Train
private extension AGEVideoContainer {
    #if os(macOS)
    func addEventsObserver() {
        eventsObserver.delegate = self
        eventsObserver.dataSource = self
        eventsObserver.listenCurrentWindow(inputEvents: .leftMouseUp)
    }
    
    #else
    func addTapGesture() {
        let recognizer = UITapGestureRecognizer(target: self, action: nil)
        recognizer.numberOfTapsRequired = 1
        recognizer.delegate = self
        self.addGestureRecognizer(recognizer)
    }
    #endif
}

#if os(iOS)
extension AGEVideoContainer: UIGestureRecognizerDelegate {
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let position = gestureRecognizer.location(in: self)
       
        findSelectedViewCommonSteps(with: AGEEvent(),
                                    scrollNeedPosition: position)
        
        return true
    }
}
#endif

#if os(macOS)
extension AGEVideoContainer: AGEEventsObserverDelegate {
    func observer(_ observer: AGEEventsObserver, didTriggerInputEvent event: NSEvent) {
        findSelectedViewOnMacSteps(with: event)
    }
}

extension AGEVideoContainer: AGEEventsObserverDataSource {
    func observerNeedWindowNumber(_ observer: AGEEventsObserver) -> Int {
        guard let windowNumber = self.window?.windowNumber else {
            return -1
        }
        
        return windowNumber
    }
}
#endif

private extension AGEVideoContainer {
    #if os(macOS)
    typealias AGEEvent = NSEvent
    #else
    typealias AGEEvent = UIEvent
    #endif
    
    struct PositionCheckResult {
        var isContain: Bool
        var convertedPosition: CGPoint
    }
    
    #if os(macOS)
    func findSelectedViewOnMacSteps(with event: AGEEvent) {
        guard let windowContentView = self.window?.contentView else {
            return
        }
        
        // Step 1, check AGEContainer contains this position
        let containerResult = check(superView: windowContentView,
                                    position: event.locationInWindow,
                                    isContainedBy: self)
        
        guard containerResult.isContain else {
            return
        }
        
        findSelectedViewCommonSteps(with: event,
                                    scrollNeedPosition: containerResult.convertedPosition)
    }
    #endif
    
    func findSelectedViewCommonSteps(with event: AGEEvent, scrollNeedPosition: CGPoint) {
        // Step 2, check per level layoutView contains this position
        var containedLevels = [(level: Int, convertedPosition: CGPoint)]()
        
        for (level, item) in levels {
            let view = item.viewType.view
            let scrollViewResult = check(superView: self,
                                     position: scrollNeedPosition,
                                     isContainedBy: view)
            
            if scrollViewResult.isContain {
                containedLevels.append((level,
                                        scrollViewResult.convertedPosition))
            }
        }
        
        containedLevels.sort { (num1, num2) -> Bool in
            return num1.level > num2.level
        }
        
        guard containedLevels.count > 0 else {
                return
        }

        var containedSubIndex: AGEIndex?
        var containedSubView: AGEView?
        
        for item in containedLevels {
            guard let subViewsOfScroll = viewsOfList(level: item.level),
                let scrollView = levels[item.level]?.viewType.view else {
                    continue
            }
            
            // Step 3, check per item view of layoutView contains this position
            var subViewResult = PositionCheckResult(isContain: false,
                                                    convertedPosition: CGPoint.zero)
            
            for (index, view) in subViewsOfScroll.enumerated() {
                subViewResult = check(superView: scrollView,
                                      position: item.convertedPosition,
                                      isContainedBy: view)
                
                if subViewResult.isContain {
                    containedSubIndex = AGEIndex(level: item.level, item: index)
                    containedSubView = view
                    break
                }
            }
            
            if containedSubIndex != nil {
                break
            }
        }
        
        guard let subIndex = containedSubIndex,
            let subView = containedSubView else {
                return
        }

        AGELog.log("selected index, level: \(subIndex.level), item: \(subIndex.item)", type: .eventsTrain)
        
        delegate?.container(self, didSelected: subView, index: subIndex)
    }
    
    func check(superView: AGEView, position: CGPoint, isContainedBy subView: AGEView) -> PositionCheckResult {
        let convertedPoint = superView.convert(position, to: subView)
        let isContain = subView.bounds.contains(convertedPoint)
        AGELog.log("position, x:\(position.x), y: \(position.y)", type: .eventsTrain)
        AGELog.log("convertedPoint, x:\(convertedPoint.x), y: \(convertedPoint.y), isContain:\(isContain)", type: .eventsTrain)
        AGELog.log("subView frame, x:\(subView.frame.origin.x), y: \(subView.frame.origin.y), w: \(subView.frame.width), h: \(subView.frame.height)", type: .eventsTrain)
        AGELog.log(AGELog.separator, type: .eventsTrain)
        return PositionCheckResult(isContain: isContain,
                                   convertedPosition: convertedPoint)
    }
}

extension AGEVideoContainer: AGELayoutViewDataSource {
    func layoutViewNeedItemViews(_ layoutView: AGELayoutView) -> [AGEView]? {
        return viewsOfList(level: layoutView.level)
    }
    
    func layoutViewNeedLayout(_ layoutView: AGELayoutView) -> AGEVideoLayout? {
        return levels[layoutView.level]?.layout
    }
}

// MARK: - AGELayoutViewDelegate
extension AGEVideoContainer: AGELayoutViewDelegate {
    #if os(iOS)
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
    }
    
    #else
    func scrollViewDidScroll(_ scrollView: AGELayoutView) {
    }
    #endif
    
    func layoutView(_ layoutView: AGELayoutView, itemViewWillDisplay index: Int) {
        let ageIndex = AGEIndex(level: layoutView.level, item: index)
        delegate?.container(self, itemWillDisplay: ageIndex)
        AGELog.log("itemViewWillDisplay: \(ageIndex)", type: .willHiddenItemView)
    }
    
    func layoutView(_ layoutView: AGELayoutView, itemViewDidHidden index: Int) {
        let ageIndex = AGEIndex(level: layoutView.level, item: index)
        delegate?.container(self, itemDidHidden: ageIndex)
        AGELog.log("itemViewDidHidden: \(ageIndex)", type: .willHiddenItemView)
    }
}

fileprivate extension AGEView {
    func privateRemoveConstraints(_ constraints: [NSLayoutConstraint]) {
        #if os(iOS)
        if #available(iOS 10.0 , *) {
            NSLayoutConstraint.deactivate(constraints)
        } else {
            removeConstraints(constraints)
        }
        #else
        NSLayoutConstraint.deactivate(constraints)
        #endif
    }
}
