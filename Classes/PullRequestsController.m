#import "PullRequestsController.h"
#import "PullRequestController.h"
#import "GHPullRequest.h"
#import "GHPullRequests.h"
#import "GHRepository.h"
#import "IssueObjectCell.h"
#import "iOctocat.h"
#import "SVProgressHUD.h"


@interface PullRequestsController ()
@property(nonatomic,readonly)GHPullRequests *currentPullRequests;
@property(nonatomic,strong)GHRepository *repository;
@property(nonatomic,strong)NSArray *objects;
@property(nonatomic,strong)IBOutlet UISegmentedControl *pullRequestsControl;
@property(nonatomic,strong)IBOutlet UITableViewCell *loadingPullRequestsCell;
@property(nonatomic,strong)IBOutlet UITableViewCell *noPullRequestsCell;
@end


@implementation PullRequestsController

- (id)initWithRepository:(GHRepository *)repo {
	self = [super initWithNibName:@"PullRequests" bundle:nil];
	if (self) {
		self.repository = repo;
		self.objects = @[self.repository.openPullRequests, self.repository.closedPullRequests];
	}
	return self;
}

#pragma mark View Events

- (void)viewDidLoad {
	[super viewDidLoad];
	self.navigationItem.title = self.title ? self.title : @"Pull Requests";
	self.navigationItem.titleView = self.pullRequestsControl;
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh:)];
	self.pullRequestsControl.selectedSegmentIndex = 0;
}

- (void)viewWillAppear:(BOOL)animated {
	[self switchChanged:nil];
}

#pragma mark Helpers

- (GHIssues *)currentPullRequests {
	NSInteger idx = self.pullRequestsControl.selectedSegmentIndex;
	return idx == UISegmentedControlNoSegment ? nil : self.objects[idx];
}

- (BOOL)resourceHasData {
	return self.currentPullRequests.isLoaded && !self.currentPullRequests.isEmpty;
}

#pragma mark Actions

- (IBAction)switchChanged:(id)sender {
	[self.tableView reloadData];
	[self.tableView setContentOffset:CGPointZero animated:NO];
	if (self.currentPullRequests.isLoaded) return;
	[self.currentPullRequests loadWithParams:nil success:^(GHResource *instance, id data) {
		[self.tableView reloadData];
	} failure:^(GHResource *instance, NSError *error) {
		[iOctocat reportLoadingError:@"Could not load the pull requests"];
	}];
	[self.tableView reloadData];
}

- (IBAction)refresh:(id)sender {
	[SVProgressHUD showWithStatus:@"Reloading…"];
	[self.currentPullRequests loadWithParams:nil success:^(GHResource *instance, id data) {
		[SVProgressHUD dismiss];
		[self.tableView reloadData];
	} failure:^(GHResource *instance, NSError *error) {
		[SVProgressHUD showErrorWithStatus:@"Reloading failed"];
	}];
}

- (void)reloadPullRequests {
	for (GHPullRequests *pullRequests in self.objects) [pullRequests markAsUnloaded];
}

#pragma mark TableView

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.resourceHasData ? self.currentPullRequests.count : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (self.currentPullRequests.isLoading) return self.loadingPullRequestsCell;
	if (self.currentPullRequests.isEmpty) return self.noPullRequestsCell;
	IssueObjectCell *cell = (IssueObjectCell *)[tableView dequeueReusableCellWithIdentifier:kIssueObjectCellIdentifier];
	if (cell == nil) cell = [IssueObjectCell cell];
	cell.issueObject = self.currentPullRequests[indexPath.row];
	if (self.repository) [cell hideRepo];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	if (!self.resourceHasData) return;
	GHPullRequest *pullRequest = self.currentPullRequests[indexPath.row];
	PullRequestController *viewController = [[PullRequestController alloc] initWithPullRequest:pullRequest andListController:self];
	[self.navigationController pushViewController:viewController animated:YES];
}

@end