import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:githao/network/api_service.dart';
import 'package:githao/network/entity/repo_entity.dart';
import 'package:githao/pages/home.dart';
import 'package:githao/pages/profile.dart';
import 'package:githao/resources/custom_icons_icons.dart';
import 'package:githao/resources/lang_colors.dart';
import 'package:githao/resources/repos_filter_parameters.dart';
import 'package:githao/resources/starred_filter_parameters.dart';
import 'package:githao/widgets/loading_state.dart';
import 'package:githao/utils/util.dart';
import 'package:githao/widgets/starred_repos_filter.dart';
import 'package:intl/intl.dart';

import 'load_more_data_footer.dart';
import 'my_repos_filter.dart';
import 'my_visibility.dart';

/// [perPageRows] 每次请求期望返回的数据量，GitHub默认每次返回30条数据；
/// [needLoadMore] 为true时，提供上拉加载更多特性；
class MyReposWidget extends StatefulWidget{
  final perPageRows = 30;
  final bool needLoadMore;
  final String homeDrawerMenu;
  MyReposWidget({Key key, this.homeDrawerMenu, this.needLoadMore=true,}): super(key: key);
  @override
  _MyReposWidgetState createState() => _MyReposWidgetState();
}

class _MyReposWidgetState extends State<MyReposWidget> {
  final List<RepoEntity> _repos = [];
  int _page = 1;
  StateFlag _loadingState = StateFlag.idle;
  bool _expectHasMoreData = true;
  int _groupTypeIndex = 0;
  int _groupSortIndex = 0;
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshIndicatorKey.currentState.show());
  }

  void onClickFilterCallback(String group, int index) {
    if (widget.homeDrawerMenu == HomeDrawer.MENU_MY_REPOS) {
      if(group == MyReposFilter.GROUP_TYPE && _groupTypeIndex != index) {
        setState(() {
          _groupTypeIndex = index;
        });
        _refreshIndicatorKey.currentState.show();
      } else if(group == MyReposFilter.GROUP_SORT && _groupSortIndex != index) {
        setState(() {
          _groupSortIndex = index;
        });
        _refreshIndicatorKey.currentState.show();
      }
    } else if (widget.homeDrawerMenu == HomeDrawer.MENU_STARRED_REPOS) {
      if(group == StarredReposFilter.GROUP_SORT && _groupSortIndex != index) {
        setState(() {
          _groupSortIndex = index;
        });
        _refreshIndicatorKey.currentState.show();
      }
    }
  }
  Future<void> _loadData({bool isReload=true}) async {
    if(_loadingState == StateFlag.loading) return null;
    _loadingState = StateFlag.loading;
    int expectationPage;
    if (isReload) {
      setState(() {
        _repos.clear();
        _page = 1;
      });
      expectationPage = 1;
    } else {
      expectationPage = _page + 1;
    }
    Future<List<RepoEntity>> future;
    if(widget.homeDrawerMenu == HomeDrawer.MENU_MY_REPOS) {
      String _type = ReposFilterParameters.filterTypeValueMap[_groupTypeIndex];
      String _sort = ReposFilterParameters.filterSortValueMap[_groupSortIndex][ReposFilterParameters.PARAMETER_NAME_SORT];
      String _direction = ReposFilterParameters.filterSortValueMap[_groupSortIndex][ReposFilterParameters.PARAMETER_NAME_DIRECTION];
      future = ApiService.getRepos(page: expectationPage, type: _type, sort: _sort, direction: _direction);
    } else if(widget.homeDrawerMenu == HomeDrawer.MENU_STARRED_REPOS) {
      String _sort = StarredFilterParameters.filterSortValueMap[_groupSortIndex][StarredFilterParameters.PARAMETER_NAME_SORT];
      String _direction = StarredFilterParameters.filterSortValueMap[_groupSortIndex][StarredFilterParameters.PARAMETER_NAME_DIRECTION];
      future = ApiService.getStarredRepos(page: expectationPage, sort: _sort, direction: _direction);
    }
    return future.then<bool>((list) {
      if(mounted) {
        setState(() {
          if(list.isNotEmpty) {
            this._repos.addAll(list);
            if (!isReload) {
              ++_page;
            }
          }
          //判断是否还有更多数据
          this._expectHasMoreData = list.length >= widget.perPageRows;
          if(isReload && list.isEmpty) {
            this._loadingState = StateFlag.empty;
          } else {
            this._loadingState = StateFlag.complete;
          }
        });
      }
      return;
    }).catchError((e) {
      if(mounted) {
        if(isReload) {
          setState(() {
            _repos.clear();
            this._loadingState = StateFlag.error;
          });
        }
        Util.showToast(e is DioError ? e.message : e.toString());
      }
      return;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        MyVisibility(
          flag: this._loadingState != StateFlag.empty && this._loadingState != StateFlag.error ? MyVisibilityFlag.visible : MyVisibilityFlag.gone,
          child: Container(
            color: Theme.of(context).primaryColorLight,
            child: RefreshIndicator(
              key: _refreshIndicatorKey,
              color: Colors.blue,
              onRefresh: _loadData,
              child: NotificationListener(
                onNotification: (ScrollNotification notification) {
                  if(widget.needLoadMore && _expectHasMoreData) { //是否需要实现加载更多特性
                    if(0 == notification.metrics.extentAfter) { //到达底部
                      _loadData(isReload: false);
                    }
                  }
                  return false; //返回false，将事件传递给外层控件(RefreshIndicator)，否则外层RefreshIndicator无法监听到下拉手势
                },
                child: ListView.builder(
                  padding: EdgeInsets.all(0.0),
                  itemCount: (_repos.length >= widget.perPageRows && widget.needLoadMore) ? _repos.length+1 : _repos.length,
                  itemBuilder: (context, index) {
                    if(index < _repos.length) {
                      return _getRepoItem(index);
                    } else {
                      return LoadMoreDataFooter(_expectHasMoreData);
                    }
                  },
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          right: 16,
          child: FloatingActionButton(
            child: Icon(Icons.sort),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (BuildContext context) {
                  return widget.homeDrawerMenu == HomeDrawer.MENU_STARRED_REPOS
                      ? StarredReposFilter(
                      this._groupSortIndex,
                      StarredFilterParameters.getFilterSortTextMap(context),
                      onClickFilterCallback)
                      : MyReposFilter(
                      this._groupTypeIndex,
                      ReposFilterParameters.getFilterTypeTextMap(context),
                      this._groupSortIndex,
                      ReposFilterParameters.getFilterSortTextMap(context),
                      onClickFilterCallback);
                },
              );
            },
          ),
        ),
        LoadingState(_loadingState,
          onRetry: (){
            _refreshIndicatorKey.currentState.show();
          },
        ),
      ],
    );
  }

  Widget _getRepoItem(int index) {
    return Card(
      margin: EdgeInsets.only(left: 8, top: 8, right: 8, bottom: (index +1 == _repos.length) ? 8 : 0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: () {
                Navigator.pushNamed(context, ProfilePage.ROUTE_NAME, arguments: _repos[index].owner.login);
              },
              child: CircleAvatar(
                backgroundImage: CachedNetworkImageProvider(_repos[index].owner.avatarUrl),
              ),
            ),
            SizedBox(width: 16,),
            Expanded(
              flex: 1,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Offstage(
                        offstage: !_repos[index].fork,
                        child: Icon(CustomIcons.fork, color: Theme.of(context).primaryColor, size: 18,),
                      ),
                      Expanded(
                        child: Text(_repos[index].name,
                          maxLines: 2,
                          style: TextStyle(fontSize: 16, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4,),
                  MyVisibility(
                    flag: _repos[index].description == null ? MyVisibilityFlag.gone : MyVisibilityFlag.visible,
                    child: Text(_repos[index].description ?? '',
                      maxLines: 4,
                      softWrap: true,
                      style: TextStyle(),
                    ),
                  ),
                  SizedBox(height: 8,),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: <Widget>[
                      _getOwner(_repos[index].owner.login),
                      _getIssues(_repos[index].openIssues),
                      //抓包发现watchers和stargazersCount数值完全一样，应该是GitHub的bug
//                      _getWatchers(_repos[index].watchers),
                      _getStargazersCount(_repos[index].stargazersCount),
                      _getForks(_repos[index].forks),
                      _getLanguage(_repos[index].language),
                      _getPushedTime(_repos[index].pushedAt),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _getOwner(String owner) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.account_circle, color: Theme.of(context).primaryColor, size: 18,),
        SizedBox(width: 2,),
        Text(owner),
      ],
    );
  }

  Widget _getIssues(int issues) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.info, color: Theme.of(context).primaryColor, size: 18,),
        SizedBox(width: 2,),
        Text('$issues'),
      ],
    );
  }

  Widget _getWatchers(int watchers) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.remove_red_eye, color: Theme.of(context).primaryColor, size: 18,),
        SizedBox(width: 2,),
        Text('$watchers'),
      ],
    );
  }

  Widget _getStargazersCount(int count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.stars, color: Theme.of(context).primaryColor, size: 18,),
        SizedBox(width: 2,),
        Text('$count'),
      ],
    );
  }

  Widget _getForks(int forks) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(CustomIcons.fork, color: Theme.of(context).primaryColor, size: 18,),
        SizedBox(width: 2,),
        Text('$forks'),
      ],
    );
  }
  Widget _getLanguage(String language) {
    if(language != null && language.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: langColors.getColor(language),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 2,),
          Text(language),
        ],
      );
    } else {
      return Offstage(offstage: true,);
    }
  }

  Widget _getPushedTime(String time) {
    if(time == null) return Offstage(offstage: true,);
    DateTime dateTime = DateTime.parse(time).toLocal();
    DateTime now = DateTime.now();
    Duration difference = dateTime.difference(now);
    DateFormat uiFormat = DateFormat('yyyy-MM-dd HH:mm');
    String strUiDatetime = uiFormat.format(dateTime);
    if(difference.inMilliseconds < 0) {
      difference = difference.abs();
      if(dateTime.year != now.year) {
        uiFormat = DateFormat('yyyy-MM-dd');
        strUiDatetime = uiFormat.format(dateTime);
      } else if(dateTime.month != now.month) {
        uiFormat = DateFormat('MM-dd');
        strUiDatetime = uiFormat.format(dateTime);
      } else if(dateTime.day != now.day) {
        int days = difference.inDays;
        if(days == 0) ++days;
        strUiDatetime = '$days days ago';
      } else if(dateTime.hour != now.hour) {
        int hours = difference.inHours;
        if(hours == 0) ++hours;
        strUiDatetime = '$hours hours ago';
      } else if(dateTime.minute != now.minute) {
        int minutes = difference.inMinutes;
        if(minutes == 0) ++minutes;
        strUiDatetime = '$minutes minutes ago';
      } else if(dateTime.second != now.second) {
        int seconds = difference.inSeconds;
        if(seconds == 0) ++seconds;
        strUiDatetime = '$seconds seconds ago';
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.access_time, color: Theme.of(context).primaryColor, size: 18,),
        SizedBox(width: 2,),
        Text('Pushed on $strUiDatetime'),
      ],
    );
  }
  @override
  void dispose() {
    super.dispose();
  }
}