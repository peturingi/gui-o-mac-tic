import Cocoa

class MainWindowViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, SplashScreenDataSource {
    
    var splashScreenConfig: SplashScreenConfig?
    var button2Action = [NSButton: ActionItem]()
    var commands = [Command]()
    
    var statusDisplayTitleFont: NSFont?
    var statusDisplayDetailsFont: NSFont?
    
    @IBOutlet weak var background: NSImageView!
    @IBOutlet weak var substatusView: NSTableView!
    @IBOutlet weak var substatusScrollView: NSScrollView!
    @IBOutlet weak var actionStack: NSStackView!
    @IBOutlet weak var notification: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.notification.stringValue = Blackboard.shared.config?.main_window?.initial_notification ?? ""
        
        if let titleFont = Blackboard.shared.config?.fontStyles?.title {
            self.statusDisplayTitleFont = FontStyleToFontMapper.map(titleFont)
        }
        if let detailsFont = Blackboard.shared.config?.fontStyles?.details {
            self.statusDisplayDetailsFont = FontStyleToFontMapper.map(detailsFont)
        }
        if let notificationFont = Blackboard.shared.config?.fontStyles?.notification {
            self.notification.font = FontStyleToFontMapper.map(notificationFont)
        }

        
        func configureActionStack() {
            func mapPosition2Gravity(position: Position) -> NSStackView.Gravity {
                switch position {
                case .first:
                    return .leading
                case .last:
                    return .trailing
                }
            }
            Blackboard.shared.config!.main_window?.action_items.forEach { action in
                let buttonInit: ((String, Any?, Selector?) -> NSButton)
                    switch action.type {
                    case .checkbox:
                        buttonInit = NSButton.init(checkboxWithTitle:target:action:)
                    case .button:
                        buttonInit = NSButton.init(title:target:action:)
                    }
                let command = CommandFactory.build(forOperation: action.op!, withArgs: action.args)
                self.commands.append(command)
                let control = buttonInit(action.label!, command, #selector(command.execute(sender:)))
                let gravity = mapPosition2Gravity(position: action.position!)
                self.actionStack.addView(control, in: gravity)
                self.button2Action[control] = action
            }
            
            if let buttonsFont = Blackboard.shared.config?.fontStyles?.buttons {
                self.button2Action.keys.forEach { button in
                    button.font = FontStyleToFontMapper.map(buttonsFont)
                }
            }
        }
        NotificationCenter.default.addObserver(forName: Constants.SHOW_SPLASH_SCREEN, object: nil, queue: nil) { notification in
            guard
                let userInfo = notification.userInfo,
                let background = userInfo[Keyword.background.rawValue] as? NSImage,
                let message = userInfo[Keyword.message.rawValue] as? String,
                let showProgressBar = userInfo["showProgressBar"] as? Bool?,
                let messageX = userInfo["message_x"] as? Float,
                let messageY = userInfo["message_y"] as? Float
                else {
                    preconditionFailure("Observed a \(Constants.SHOW_SPLASH_SCREEN) notification without a valid userInfo.")
            }
            self.splashScreenConfig = SplashScreenConfig(message,
                                                         background,
                                                         showProgressBar ?? false,
                                                         messageX,
                                                         messageY)
            self.showSplashScreen()
        }
        
        NotificationCenter.default.addObserver(forName: Constants.SET_STATUS_DISPLAY, object: nil, queue: nil) { _ in
            self.substatusView.reloadData()
        }
        
        Blackboard.shared.addNotificationDidChange {
            self.notification.stringValue = Blackboard.shared.notification
            self.notification.sizeToFit()
        }
        
        NotificationCenter.default.addObserver(forName: Constants.DOMAIN_UPDATE, object: nil, queue: nil) { notification in
            if let actionItem = notification.object as? ActionItem {
                for (button, action) in self.button2Action {
                    if actionItem.id == action.id && actionItem.id != nil {
                        button.title = action.label ?? ""
                        self.button2Action[button] = actionItem
                        button.setNeedsDisplay()
                        return
                    }
                }
            }
        }
        
        configureActionStack()
        self.background.image = NSImage.init(withGUIOMaticImage: Blackboard.shared.config!.main_window?.image)
    }
        
    func numberOfRows(in tableView: NSTableView) -> Int {
        return Blackboard.shared.config!.main_window?.status_displays?.count ?? 0
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeView(withIdentifier: Constants.SUBSTATE_CELL_ID, owner: self) as! SubstatusTableCellView
        let status = Blackboard.shared.config!.main_window!.status_displays![row]
        
        cell.titleView.stringValue = status.title
        if self.statusDisplayTitleFont != nil {
            cell.titleView.font = self.statusDisplayTitleFont!
        }
        
        cell.descriptionView.stringValue = status.details ?? ""
        if self.statusDisplayDetailsFont != nil {
            cell.descriptionView.font = self.statusDisplayDetailsFont!
        }
        
        cell.iconView.image = status.icon
        
        if let colour = status.textColour {
            cell.titleView.textColor = colour
            cell.descriptionView.textColor = colour
        }
        
        /* Refreshes the cell in case the SetStatusDisplay command has just executed. */
        cell.setNeedsDisplay(cell.frame)
        
        return cell
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return false
    }
    
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if let targetWindowController = segue.destinationController as? NSWindowController,
            let targetViewController = targetWindowController.contentViewController as? SplashViewController {
            targetViewController.notification.stringValue = splashScreenConfig!.message
            targetViewController.imageCell.image = splashScreenConfig!.background
            targetViewController.progressIndicator.isHidden = splashScreenConfig!.showProgressIndicator == false
            targetViewController.messageX = splashScreenConfig!.messageX
            targetViewController.messageY = splashScreenConfig!.messageY
        } else {
            assertionFailure("Expected a single segue from this controller, leading to a NSWindowController.")
        }
    }
    
    func showSplashScreen() {
        performSegue(withIdentifier: Constants.SPLASH_SEGUE, sender: self)
    }
    
    /**
     Resizes this controller's view such that it shows at most `statusDisplayCount` status items in it's window.
    */
    func sizeToFit(statusDisplayCount: UInt) {
        /* Compute a height value which can show `statusDisplayCount` rows. */
        let heightWithoutScrollview = self.view.frame.height - self.substatusScrollView.frame.height
        let cellHeight = self.substatusView.rowHeight + self.substatusView.intercellSpacing.height
        let height = heightWithoutScrollview + cellHeight * CGFloat(statusDisplayCount)
        
        /* Set this controller's view's height. */
        self.view.setFrameSize(NSMakeSize(self.view.frame.width, height))
        
        /* Update the this view's window's height so the entire view will be displayed. */
        self.view.window?.setContentSize(self.view.frame.size)
    }
}
