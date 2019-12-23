//
//  ViewController.swift
//  VideoViews
//
//  Created by CavanSu on 2019/7/23.
//  Copyright © 2019 CavanSu. All rights reserved.
//

#if os(iOS)
import UIKit
#else
import Cocoa
#endif

#if os(iOS)
typealias AGEButton = UIButton
typealias AGEViewController = UIViewController
typealias AGESegmentedControl = UISegmentedControl
#else
typealias AGEButton = NSButton
typealias AGEViewController = NSViewController
typealias AGESegmentedControl = NSSegmentedControl
#endif

#if os(macOS)
extension AGESegmentedControl {
    var selectedSegmentIndex: Int {
        set {
            selectedSegment = newValue
        }
        get {
            return selectedSegment
        }
    }
}
#endif

import AGEVideoLayout

class ViewController: AGEViewController {
    
    @IBOutlet weak var containerView: AGEVideoContainer!
    @IBOutlet weak var addButton: AGEButton!
    @IBOutlet weak var deleteButton: AGEButton!
    
    #if os(macOS)
    let windowWidth: CGFloat = 780.0
    let windowHeight: CGFloat = 670.0
    #endif
    
    lazy var aView = AGEView()
    lazy var bView = AGEView()
    lazy var cView = AGEView()
    lazy var dView = AGEView()
    lazy var eView = AGEView()
    lazy var fView = AGEView()
    
    var totalViews = [AGEView]()
    var list = [AGEView]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        aView.backgroundColor = AGEColor.green
        bView.backgroundColor = AGEColor.red
        cView.backgroundColor = AGEColor.yellow
        dView.backgroundColor = AGEColor.brown
        eView.backgroundColor = AGEColor.darkGray
        fView.backgroundColor = AGEColor.cyan
        
        totalViews.append(aView)
        totalViews.append(bView)
        totalViews.append(cView)
        totalViews.append(dView)
        totalViews.append(eView)
        totalViews.append(fView)
        
        containerView.delegate = self
        
        test0()
    }
    
    #if os(macOS)
    override func viewDidAppear() {
        super.viewDidAppear()
        configStyle(of: view.window!)
    }
    #endif
    
    #if os(iOS)
    @objc func tapHandle() {
        print("b view tap")
    }
    #endif
    
    @IBAction func doSegChanged(_ sender: AGESegmentedControl) {
        hiddenButtons(true)
        
        switch sender.selectedSegmentIndex {
        case 0:
            test0()
        case 1:
            hiddenButtons(false)
            test1()
        case 2:
            test2()
        default:
            break
        }
    }
    
    @IBAction func doAddButton(_ sender: AGEButton) {
        let total = totalViews.count
        let listCount = list.count
        
        guard total > listCount else {
            return
        }
        list.insert(totalViews[(total - 1) - listCount], at: 0)
        containerView.reload(level: 0, animated: true)
    }
    
    @IBAction func doDeleteButton(_ sender: AGEButton) {
        guard let _ = list.first else {
            return
        }
        
        list.removeFirst()
        containerView.reload(level: 0, animated: true)
    }
    
    func hiddenButtons(_ hidden: Bool) {
        addButton.isHidden = hidden
        deleteButton.isHidden = hidden
    }
    
    #if os(macOS)
    func configStyle(of window: NSWindow) {
        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
        
        if window.styleMask.contains(.resizable) {
            window.styleMask.remove(.resizable)
        }
        
        let minSize = CGSize(width: windowWidth, height: windowHeight)
        window.minSize = minSize
        window.maxSize = minSize
        window.setContentSize(minSize)
    }
    #endif
}

// MARK: - Cases
extension ViewController {
    func test0() {
        list.removeAll()
        
        #if os(iOS)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapHandle))
        bView.addGestureRecognizer(tap)
        #endif
        
        list.append(bView)
        list.append(cView)
        list.append(dView)
        list.append(eView)
        
        let layout = AGEVideoLayout(level: 0)
            .startPoint(x: 0, y: 0)
            .size(.scale(CGSize(width: 1, height: 1)))
            .itemSize(.scale(CGSize(width: 0.5, height: 0.5)))
            .interitemSpacing(5)
            .lineSpacing(5)

        containerView
            .listCount { [unowned self] (level: Int) -> Int in
                return self.list.count
            }.listItem({ (index) -> AGEView in
                return self.list[index.item]
            })

        containerView.removeAllLayouts()
        containerView.setLayouts([layout])
    }
    
    func test1() {
        list.removeAll()
        
        list.append(aView)
        list.append(bView)
        list.append(cView)
        list.append(dView)
        list.append(eView)
        list.append(fView)

        let layout = AGEVideoLayout(level: 0)
            .scrollType(.scroll(.vertical))
            .size(.scale(CGSize(width: 1, height: 1)))
            .itemSize(.constant(CGSize(width: 200, height: 200)))
            .lineSpacing(10)

        containerView
            .listCount { [unowned self] (level: Int) -> Int in
                return self.list.count
            }.listItem({ (index) -> AGEView in
                return self.list[index.item]
            })

        containerView.removeLayout(level: 1)
        containerView.removeLayout(level: 2)
        containerView.setLayouts([layout], animated: true)
    }
    
    #if os(iOS)
    func test2() {
        list.removeAll()
        
        list.append(aView)
        list.append(bView)
        list.append(cView)
        list.append(dView)
        list.append(eView)
        list.append(fView)

        let fullLayout = AGEVideoLayout(level: 0)
            .startPoint(x: 0, y: 0)
            .size(.scale(CGSize(width: 1, height: 1)))
            .itemSize(.scale(CGSize(width: 1, height: 1)))
        
        let previewLayout = AGEVideoLayout(level: 1)
            .startPoint(x: 200, y: 0)
            .size(.scale(CGSize(width: 0.25, height: 0.25)))
            .itemSize(.scale(CGSize(width: 1, height: 1)))

        let scrollLayout = AGEVideoLayout(level: 2)
            .startPoint(x: 0, y: self.containerView.bounds.height - 120)
            .scrollType(.scroll(.horizontal))
            .size(.constant(CGSize(width: self.containerView.bounds.width, height: 100)))
            .itemSize(.constant(CGSize(width: 200, height: 100)))
            .interitemSpacing(10)

        containerView
            .listCount { [unowned self] (level: Int) -> Int in
                if level == 0 {
                    return 1
                } else if level == 1 {
                    return 1
                } else {
                    return self.list.count - 2
                }
            }.listItem({ (index) -> AGEView in
                if index.level == 0 {
                    return self.aView
                } else if index.level == 1 {
                    return self.bView
                } else {
                    return self.list[index.item + 2]
                }
            })

        containerView.setLayouts([fullLayout, previewLayout, scrollLayout], animated: true)
    }
    
    #else
    func test2() {
        list.removeAll()
        
        list.append(aView)
        list.append(bView)
        list.append(cView)
        list.append(dView)
        list.append(eView)
        list.append(fView)
        
        let fullLayout = AGEVideoLayout(level: 0)
        
        let scrollHeight = windowHeight - 100 - 91 - 65
        
        let scrollLayout = AGEVideoLayout(level: 1)
            .scrollType(.scroll(.vertical))
            .startPoint(x: 30, y: 91)
            .size(.constant(CGSize(width: 200, height: scrollHeight)))
            .itemSize(.constant(CGSize(width: 200, height: 150)))
        
        containerView
            .listCount { [unowned self] (level) -> Int in
                if level == 0 {
                    return 1
                } else {
                    return self.list.count - 1
                }
        }.listItem { [unowned self] (index) -> NSView in
            if index.level == 0 {
                return self.list[index.item]
            } else {
                return self.list[index.item + 1]
            }
        }
        
        containerView.setLayouts([fullLayout, scrollLayout], animated: false)
    }
    #endif
}

extension ViewController: AGEVideoContainerDataSource {
    func container(_ container: AGEVideoContainer, numberOfItemsIn level: Int) -> Int {
        return list.count
    }
    
    func container(_ container: AGEVideoContainer, viewForItemAt index: AGEIndex) -> AGEView {
        return list[index.item]
    }
}

extension ViewController: AGEVideoContainerDelegate {
    func container(_ container: AGEVideoContainer, didSelected subView: AGEView, index: AGEIndex) {
        print("index: \(index.description)")
    }
}
