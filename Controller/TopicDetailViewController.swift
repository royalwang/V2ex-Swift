//
//  TopicDetailViewController.swift
//  V2ex-Swift
//
//  Created by huangfeng on 1/16/16.
//  Copyright © 2016 Fin. All rights reserved.
//

import UIKit
import SVProgressHUD
class TopicDetailViewController: BaseViewController, UITableViewDelegate,UITableViewDataSource ,UIActionSheetDelegate ,V2ActivityViewDataSource{

    var topicId = "0"
    var currentPage = 1

    private var model:TopicDetailModel?
    private var commentsArray:[TopicCommentModel] = []
    private var webViewContentCell:TopicDetailWebViewContentCell?
    
    private var _tableView :UITableView!
    private var tableView: UITableView {
        get{
            if(_tableView != nil){
                return _tableView!;
            }
            _tableView = UITableView();
            _tableView.separatorStyle = UITableViewCellSeparatorStyle.None;
            
            _tableView.backgroundColor = V2EXColor.colors.v2_backgroundColor
            regClass(_tableView, cell: TopicDetailHeaderCell.self)
            regClass(_tableView, cell: TopicDetailWebViewContentCell.self)
            regClass(_tableView, cell: TopicDetailCommentCell.self)
            regClass(_tableView, cell: BaseDetailTableViewCell.self)
            
            _tableView.delegate = self
            _tableView.dataSource = self
            return _tableView!;
            
        }
    }
    
    //MARK: - 页面事件
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "帖子详情"
        self.view.backgroundColor = V2EXColor.colors.v2_backgroundColor
        self.view.addSubview(self.tableView);
        self.tableView.snp_makeConstraints{ (make) -> Void in
            make.top.right.bottom.left.equalTo(self.view);
        }
        
        let rightButton = UIButton(frame: CGRectMake(0, 0, 40, 40))
        rightButton.contentMode = .Center
        rightButton.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, -15)
        rightButton.setImage(UIImage(named: "ic_more_horiz_36pt")!.imageWithRenderingMode(.AlwaysTemplate), forState: .Normal)
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightButton)
        rightButton.addTarget(self, action: Selector("rightClick"), forControlEvents: .TouchUpInside)
        
        //根据 topicId 获取 帖子信息 、回复。
        TopicDetailModel.getTopicDetailById(self.topicId){
            (response:V2ValueResponse<(TopicDetailModel?,[TopicCommentModel])>) -> Void in
            if response.success {
                
                if let aModel = response.value!.0{
                    self.model = aModel
                }
                
                self.commentsArray = response.value!.1
                
                self.tableView.reloadData()
            }
            self.hideLoadingView()
        }
        
        self.tableView.mj_footer = V2RefreshFooter(refreshingBlock: {[weak self] () -> Void in
            self?.getNextPage()
        })
        
        self.showLoadingView()
    }
    
    
    func getNextPage(){
        if self.model == nil || self.commentsArray.count <= 0 {
            self.endRefreshingWithNoMoreData("暂无评论")
            return;
        }
        self.currentPage++
        
        if self.currentPage > self.model?.totalPages {
            self.endRefreshingWithNoMoreData("没有更多评论了")
            return;
        }
        
        TopicDetailModel.getTopicCommentsById(self.topicId, page: self.currentPage) { (response) -> Void in
            if response.success {
                self.commentsArray += response.value!
                self.tableView.reloadData()
                self.tableView.mj_footer.endRefreshing()
                
                if self.currentPage == self.model?.totalPages {
                    self.endRefreshingWithNoMoreData("没有更多评论了")
                }
                
            }
            else{
                self.currentPage--
            }
        }
    }
    
    func endRefreshingWithNoMoreData(noMoreString:String){
        (self.tableView.mj_footer as! V2RefreshFooter).noMoreDataStateString = noMoreString
        self.tableView.mj_footer.endRefreshingWithNoMoreData()
    }
    

    //MARK: - UITableView DataSource
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            if self.model != nil{
                return 3
            }
            else{
                return 0
            }
        }
        else if section == 1{
            return self.commentsArray.count;
        }
        else {
            return 0;
        }
    }
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if indexPath.section == 0 {
            
            if indexPath.row == 0{
                return tableView.fin_heightForCellWithIdentifier(TopicDetailHeaderCell.self, indexPath: indexPath) { (cell) -> Void in
                    cell.bind(self.model!);
                }
            }
            
            else if indexPath.row == 1 {
                if self.webViewContentCell?.contentHeight > 0 {
                    return self.webViewContentCell!.contentHeight
                }
                else {
                    return 1
                }
            }
            
            else if indexPath.row == 2 {
                return 45
            }
            
        }
       
        else {
            let layout = self.commentsArray[indexPath.row].textLayout!
            return layout.textBoundingRect.size.height + 12 + 35 + 12 + 12 + 1
        }
        
        return 200 ;
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            if indexPath.row == 0{
                //帖子标题
                let cell = getCell(tableView, cell: TopicDetailHeaderCell.self, indexPath: indexPath);
                cell.bind(self.model!);
                return cell;
            }
            else if indexPath.row == 1{
                //帖子内容
                if self.webViewContentCell == nil {
                    self.webViewContentCell = getCell(tableView, cell: TopicDetailWebViewContentCell.self, indexPath: indexPath);
                }
                else {
                    return self.webViewContentCell!
                }
                self.webViewContentCell!.load(self.model!);
                self.webViewContentCell!.contentHeightChanged = { [weak self] (height:CGFloat) -> Void  in
                    if let weakSelf = self {
                        //在cell显示在屏幕时更新，否则会崩溃会崩溃会崩溃
                        if weakSelf.tableView.visibleCells.contains(weakSelf.webViewContentCell!) {
                            if weakSelf.webViewContentCell?.contentHeight > 1.5 * SCREEN_HEIGHT{ //太长了就别动画了。。
                                UIView.animateWithDuration(0, animations: { () -> Void in
                                    self?.tableView.beginUpdates()
                                    self?.tableView.endUpdates()
                                })
                            }
                            else {
                                self?.tableView.beginUpdates()
                                self?.tableView.endUpdates()
                            }
                        }
                    }
                }
                return self.webViewContentCell!
            }
            
            else if indexPath.row == 2 {
                let cell = getCell(tableView, cell: BaseDetailTableViewCell.self, indexPath: indexPath)
                cell.detailMarkHidden = true
                cell.titleLabel?.text = self.model?.topicCommentTotalCount
                cell.titleLabel?.font = v2Font(12)
                cell.backgroundColor = V2EXColor.colors.v2_CellWhiteBackgroundColor
                cell.separator?.image = createImageWithColor(self.view.backgroundColor!)
                return cell
            }
        }
            
        else if indexPath.section == 1{
            //帖子评论
            let cell = getCell(tableView, cell: TopicDetailCommentCell.self, indexPath: indexPath)
            cell.bind(self.commentsArray[indexPath.row])
            return cell
        }
        return UITableViewCell();
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 1 {
            let actionSheet = UIActionSheet(title: nil, delegate: self, cancelButtonTitle: "取消", destructiveButtonTitle: nil, otherButtonTitles: "回复", "感谢" ,"查看对话")
            actionSheet.tag = indexPath.row
            actionSheet.showInView(self.view)
        }
    }
    
    func actionSheet(actionSheet: UIActionSheet, clickedButtonAtIndex buttonIndex: Int) {
        
        tableView .deselectRowAtIndexPath(NSIndexPath(forRow: actionSheet.tag, inSection: 1), animated: true);
        switch buttonIndex {
        case 1 : //回复
            let item = self.commentsArray[actionSheet.tag]
            let replyViewController = ReplyingViewController()
            replyViewController.atSomeone = "@" + item.userName! + " "
            replyViewController.topicModel = self.model!
            let nav = V2EXNavigationController(rootViewController:replyViewController)
            self.navigationController?.presentViewController(nav, animated: true, completion:nil)
            
        case 2://感谢
            let row = actionSheet.tag
            let item = self.commentsArray[row]
            if item.replyId == nil {
                SVProgressHUD.showErrorWithStatus("回复replyId为空")
                return;
            }
            if self.model?.token == nil {
                SVProgressHUD.showErrorWithStatus("帖子token为空")
                return;
            }
            item.favorites++
            self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: row, inSection: 1)], withRowAnimation: .None)
            
            TopicCommentModel.replyThankWithReplyId(item.replyId!, token: self.model!.token!) {
                [weak item, weak self](response) in
                if response.success {
                }
                else{
                    SVProgressHUD.showSuccessWithStatus("感谢失败了")
                    //失败后 取消增加的数量
                    item?.favorites--
                    self?.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: row, inSection: 1)], withRowAnimation: .None)
                }
            }
        case 3:
            let row = actionSheet.tag
            let item = self.commentsArray[row]
            let relevantComments = TopicCommentModel.getRelevantCommentsInArray(self.commentsArray, firstComment: item)
            if relevantComments.count <= 0 {
                return;
            }
            let controller = RelevantCommentsNav(comments: relevantComments)
            self.navigationController?.presentViewController(controller, animated: true, completion: nil)
        default :
            break
        }
    }
    
    //MARK: - V2ActivityView
    
    //只在activityView 显示在屏幕上持有它，如果activityView释放了，这里也一起释放。
    weak var activityView:V2ActivityViewController?
    func rightClick(){
        if  self.model != nil {
            let activityView = V2ActivityViewController()
            activityView.dataSource = self
            self.navigationController!.presentViewController(activityView, animated: true, completion: nil)
            self.activityView = activityView
        }
    }
    
    func reply(){
        self.activityView?.dismiss()
        let replyViewController = ReplyingViewController()
        replyViewController.topicModel = self.model!
        let nav = V2EXNavigationController(rootViewController:replyViewController)
        self.navigationController?.presentViewController(nav, animated: true, completion:nil)
    }
    
    
    func V2ActivityView(activityView: V2ActivityViewController, numberOfCellsInSection section: Int) -> Int {
        return 4
    }
    func V2ActivityView(activityView: V2ActivityViewController, ActivityAtIndexPath indexPath: NSIndexPath) -> V2Activity {
        return V2Activity(title: ["忽略","收藏","感谢","Safari"][indexPath.row], image: UIImage(named: ["ic_block_48pt","ic_grade_48pt","ic_favorite_48pt","ic_explore_48pt"][indexPath.row])!)
    }
    func V2ActivityView(activityView:V2ActivityViewController ,heightForFooterInSection section: Int) -> CGFloat{
        return 45
    }
    func V2ActivityView(activityView:V2ActivityViewController ,viewForFooterInSection section: Int) ->UIView?{
        let view = UIView()
        view.backgroundColor = V2EXColor.colors.v2_ButtonBackgroundColor
        
        let label = UILabel()
        label.font = v2Font(18)
        label.text = "回  复"
        label.textAlignment = .Center
        label.textColor = UIColor.whiteColor()
        view.addSubview(label)
        label.snp_makeConstraints{ (make) -> Void in
            make.top.right.bottom.left.equalTo(view)
        }
        
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: "reply"))
        
        return view
    }
    
    /// 忽略成功后调用的闭包
    var ignoreTopicHandler : ((String) -> Void)?
    func V2ActivityView(activityView: V2ActivityViewController, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        activityView.dismiss()
        //                                     用safari打开是不用登录的
        if !V2Client.sharedInstance.isLogin && indexPath.row != 3 {
            SVProgressHUD.showWithStatus("请先登录")
            return;
        }
        switch indexPath.row {
        case 0:
            SVProgressHUD.show()
            if let topicId = self.model?.topicId  {
                TopicDetailModel.ignoreTopicWithTopicId(topicId, completionHandler: {[weak self] (response) -> Void in
                    if response.success {
                        SVProgressHUD.showSuccessWithStatus("忽略成功")
                        self?.navigationController?.popViewControllerAnimated(true)
                        self?.ignoreTopicHandler?(topicId)
                    }
                    else{
                        SVProgressHUD.showErrorWithStatus("忽略失败")
                    }
                })
            }
        case 1:
            SVProgressHUD.show()
            if let topicId = self.model?.topicId ,let token = self.model?.token {
                TopicDetailModel.favoriteTopicWithTopicId(topicId, token: token, completionHandler: { (response) -> Void in
                    if response.success {
                        SVProgressHUD.showSuccessWithStatus("收藏成功")
                    }
                    else{
                        SVProgressHUD.showErrorWithStatus("收藏失败")
                    }
                })
            }
        case 2:
            SVProgressHUD.show()
            if let topicId = self.model?.topicId ,let token = self.model?.token {
                TopicDetailModel.topicThankWithTopicId(topicId, token: token, completionHandler: { (response) -> Void in
                    if response.success {
                        SVProgressHUD.showSuccessWithStatus("成功送了一波铜币")
                    }
                    else{
                        SVProgressHUD.showErrorWithStatus("没感谢成功，再试一下吧")
                    }
                })
            }
        case 3:
            UIApplication.sharedApplication().openURL(NSURL(string: V2EXURL + "t/" + self.model!.topicId!)!)
        default: break
        }
    }
    
    
}
