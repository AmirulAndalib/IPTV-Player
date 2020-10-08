import 'dart:async' show Future, runZonedGuarded;

import 'package:animations/animations.dart'
    show FadeThroughTransition, PageTransitionSwitcher;
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart'
    show
        DiagnosticPropertiesBuilder,
        DiagnosticsProperty,
        IntProperty,
        Key,
        StringProperty,
        required;
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:get/route_manager.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:logger/logger.dart' show Logger;
import 'package:url_launcher/url_launcher.dart' show canLaunch, launch;
import 'package:video_player/video_player.dart'
    show VideoPlayer, VideoPlayerController;

import 'Controllers/catalog_provider.dart' show catalog;
import 'Controllers/geoip.dart' show GetIp;
import 'Controllers/iptv_cat.dart' show countryData;
import 'Controllers/iptv_org.dart' show ipTvOrgCatalog;
import 'Models/channels.dart';
import 'Models/favorite.dart';
import 'Models/iptvcat_model.dart';
import 'Theme/theme.dart' show dartkTheme;
import 'Util/countires.dart' show countries;
import 'Util/util.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter().whenComplete(
    () async {
      Hive
        ..registerAdapter(
          FavoriteAdapter(),
        )
        ..registerAdapter(
          ChannelsAdapter(),
        )
        ..registerAdapter(
          CountryAdapter(),
        )
        ..registerAdapter(
          TvgAdapter(),
        )
        ..registerAdapter(
          IPTVCATMODELAdapter(),
        );
      await Hive.openBox<Favorite>(
        'Favorite',
      );
    },
  ).whenComplete(
    () async => runZonedGuarded(
      () async => runApp(
        const ProviderScope(
          child: Root(),
        ),
      ),
      (err, stk) => Logger().e('$err $stk'),
    ),
  );
}

class Root extends HookWidget {
  const Root({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
        future: Future.sync(() => GetIp().figureOut()),
        builder: (context, __) => GetMaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: dartkTheme,
          title: '📺 IPTV',
          home: const Home(),
        ),
      );
}

class Home extends HookWidget {
  const Home({Key key}) : super(key: key);

  static const _catalogs = [IptvCatChannels(), IptvOrgChannels()];

  @override
  Widget build(BuildContext context) {
    final _pageIndex = useProvider(catalog);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: MediaQuery.of(context).size.width > 500
          ? Scaffold(
              body: Row(
                children: <Widget>[
                  const SideBar(
                    isMobile: false,
                  ),
                  Expanded(
                    child: PageTransitionSwitcher(
                      transitionBuilder:
                          (child, primaryAnimation, secondaryAnimation) =>
                              FadeThroughTransition(
                        secondaryAnimation: secondaryAnimation,
                        animation: primaryAnimation,
                        child: child,
                      ),
                      child: _catalogs.elementAt(_pageIndex.state),
                    ),
                  ),
                ],
              ),
              floatingActionButton: _fab,
            )
          : Scaffold(
              body: PageTransitionSwitcher(
                transitionBuilder:
                    (child, primaryAnimation, secondaryAnimation) =>
                        FadeThroughTransition(
                  secondaryAnimation: secondaryAnimation,
                  animation: primaryAnimation,
                  child: child,
                ),
                child: _catalogs.elementAt(_pageIndex.state),
              ),
              bottomNavigationBar: const SideBar(
                isMobile: true,
              ),
              floatingActionButton: _fab,
            ),
    );
  }

  FloatingActionButton get _fab => FloatingActionButton.extended(
        backgroundColor: const Color.fromARGB(255, 48, 48, 48),
        label: const Text(
          'Custom url',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        icon: const Icon(
          Icons.edit,
          color: Color(0xffFCCFA8),
        ),
        onPressed: () async => Get.dialog(
          const CustomDialog(),
          useRootNavigator: false,
        ),
      );
}

class CustomDialog extends HookWidget {
  const CustomDialog({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _url = useState('https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8');

    return AlertDialog(
      title: const Text('Enter .m3u8 url'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * .9,
        child: TextFormField(
          decoration: const InputDecoration(
            icon: Icon(Icons.link),
          ),
          initialValue: 'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (newValue) => _url.value = newValue,
          validator: (url) => !url.startsWith('https')
              ? 'url must start with https'
              : !url.endsWith('.m3u8')
                  ? 'url must end with .m3u8'
                  : null,
        ),
      ),
      actions: [
        ElevatedButton(
          onPressed: () async => Get.back(
            closeOverlays: true,
          ),
          child: const Text(
            'Cancel',
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Get.back(
              closeOverlays: true,
            );
            return Get.to(
              TvPlayer(
                url: _url.value,
                catalog: 2,
              ),
              preventDuplicates: true,
            );
          },
          child: const Text(
            'Watch',
          ),
        ),
      ],
    );
  }
}

class SideBar extends HookWidget {
  const SideBar({
    @required this.isMobile,
    Key key,
  }) : super(key: key);

  final bool isMobile;

  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
        size: isMobile ? const Size.fromHeight(52) : const Size.fromWidth(72),
        child: Flex(
            direction: isMobile ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Tooltip(
                message: 'Favorites',
                child: OutlinedButton(
                  onPressed: () async =>
                      Get.to(const FavoriteView(), preventDuplicates: true),
                  child: const Icon(
                    Icons.favorite,
                    color: Colors.red,
                  ),
                ),
              ),
              Expanded(
                child: FlatButton(
                  onPressed: () async => context.read(catalog).state = 0,
                  child: RotatedBox(
                    quarterTurns: isMobile ? 0 : 3,
                    child: const Text(
                      'IPTV-CAT',
                      style: TextStyle(
                        color: Color(
                          0xffFCCFA8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FlatButton(
                  onPressed: () async => context.read(catalog).state = 1,
                  child: RotatedBox(
                    quarterTurns: isMobile ? 0 : 3,
                    child: const Text(
                      'IPTV-ORG',
                      style: TextStyle(
                        color: Color(
                          0xffFCCFA8,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: 'Report an issue with the website.',
                child: OutlinedButton(
                  onPressed: () async {
                    const url =
                        'https://github.com/Mravuri96/IPTV-Player/issues';
                    if (await canLaunch(url)) {
                      await launch(url);
                    } else {
                      return Logger().e('Couldnt launch $url');
                    }
                  },
                  child: const Icon(Icons.bug_report),
                ),
              ),
            ]),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<bool>('isMobile', isMobile),
    );
  }
}

class IptvCatChannels extends HookWidget {
  const IptvCatChannels({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _country = useState('');
    final _countryList = useProvider(countries).filter(
      (element) =>
          element.last.contains(_country.value.toLowerCase()) ||
          element.first.contains(
            _country.value.toLowerCase(),
          ),
    );

    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverAppBar(
            backgroundColor: const Color(0xffFCCFA8),
            floating: true,
            snap: true,
            toolbarHeight: 72,
            title: TextField(
              decoration: const InputDecoration(
                enabledBorder: InputBorder.none,
                border: InputBorder.none,
                focusColor: Colors.grey,
                fillColor: Colors.grey,
                hoverColor: Colors.grey,
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.black,
                ),
              ),
              style: const TextStyle(color: Colors.black),
              cursorColor: Colors.black,
              keyboardType: TextInputType.text,
              onChanged: (value) => _country.value = value,
              toolbarOptions: const ToolbarOptions(
                paste: true,
                selectAll: true,
                copy: true,
                cut: true,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 400,
              childAspectRatio: 3 / 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            delegate: SliverChildListDelegate(
              _countryList
                  .map(
                    (_country) => ElevatedButton(
                      onPressed: () async => Get.to<IpTvCatCountryChannelGrid>(
                        IpTvCatCountryChannelGrid(countryName: _country.first),
                        preventDuplicates: true,
                      ),
                      child: GridTileBar(
                        leading: Text(
                          _country.last.toUpperCase().toFlagEmoji(),
                          textScaleFactor: 3,
                        ),
                        title: Text(
                          _country.first.toUpperCase(),
                          maxLines: 2,
                          style: const TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                  )
                  .toList(),
              addRepaintBoundaries: false,
              // childCount: _countryList.length,
            ),
          ),
        ),
      ],
    );
  }
}

class IpTvCatCountryChannelGrid extends HookWidget {
  const IpTvCatCountryChannelGrid({this.countryName, Key key})
      : super(key: key);
  final String countryName;
  @override
  Widget build(BuildContext context) {
    final _channel = useState('');

    return useProvider(
      countryData(countryName),
    ).when(
      loading: () => const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, _) => Scaffold(
        body: Center(
          child: Text('Error: $err'),
        ),
      ),
      data: (channels) {
        if (channels == null || channels.isEmpty) {
          return Scaffold(
            appBar: AppBar(
              title: Text(
                countryName.toUpperCase(),
              ),
            ),
            body: Center(
              child: Text(
                'No public channels found for $countryName 😥',
                textScaleFactor: 2,
              ),
            ),
          );
        } else {
          final _channelList = channels.filter(
            (element) => element.channel.toLowerCase().contains(
                  _channel.value.toLowerCase(),
                ),
          );
          return Scaffold(
            appBar: AppBar(
              title: Card(
                color: const Color(0xffFCCFA8),
                child: TextField(
                  decoration: const InputDecoration(
                    enabledBorder: InputBorder.none,
                    border: InputBorder.none,
                    focusColor: Colors.grey,
                    fillColor: Colors.grey,
                    hoverColor: Colors.grey,
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.black,
                    ),
                  ),
                  style: const TextStyle(color: Colors.black),
                  cursorColor: Colors.black,
                  keyboardType: TextInputType.text,
                  onChanged: (value) => _channel.value = value,
                  toolbarOptions: const ToolbarOptions(
                    paste: true,
                    selectAll: true,
                    copy: true,
                    cut: true,
                  ),
                ),
              ),
            ),
            bottomNavigationBar: SizedBox(
              height: 52,
              child: GridTileBar(
                title: Text(
                  countryName.toUpperCase(),
                  overflow: TextOverflow.clip,
                ),
                subtitle: Text(
                    'Last Updated: ${channels?.first?.lastChecked?.toString()?.substring(0, 11) ?? ''}'),
              ),
            ),
            body: Center(
              child: GridView.builder(
                primary: true,
                padding: const EdgeInsets.all(16),
                itemCount: _channelList.length,
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  childAspectRatio: 3 / 1,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (context, index) {
                  final _channel = _channelList.elementAt(index);
                  return ElevatedButton(
                    onPressed: () async => Get.to(
                      TvPlayer(
                        url: _channel.link,
                        catalog: 0,
                      ),
                      preventDuplicates: true,
                    ),
                    child: GridTileBar(
                      leading: IconButton(
                        tooltip: 'Add ${_channel.channel} to favorites',
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () async => Hive.box<Favorite>('Favorite')
                            .put(
                              _channel.channel,
                              Favorite(iptvCat: _channel),
                            )
                            .whenComplete(() async => Scaffold.of(context)
                                .showSnackBar(SnackBar(
                                    content: Text(
                                        'Added ${_channel.channel} to Favorites')))),
                      ),
                      title: Text(
                        _channel.channel,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black),
                        maxLines: 2,
                      ),
                      subtitle: Text(
                        '${int.parse(
                              _channel.mbps.removeSuffix(', ...'),
                            ) / 1000} mpbs',
                        style: const TextStyle(color: Colors.black),
                      ),
                      trailing: _channel.format == 'hd'
                          ? const Icon(
                              Icons.hd,
                              color: Colors.black,
                            )
                          : const Icon(
                              Icons.fiber_dvr,
                              color: Colors.black,
                            ),
                    ),
                  );
                },
              ),
            ),
          );
        }
      },
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      StringProperty('countryName', countryName),
    );
  }
}

class IptvOrgChannels extends HookWidget {
  const IptvOrgChannels({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final _query = useState('');
    final _channels = useProvider(ipTvOrgCatalog);

    return _channels.when(
      data: (channels) {
        final _channelList = channels.where(
          (element) =>
              element.name.toLowerCase().contains(
                    _query.value.toLowerCase(),
                  ) ||
              element.country.name.toLowerCase().contains(
                    _query.value.toLowerCase(),
                  ) ||
              element.country.code.toLowerCase().contains(
                    _query.value.toLowerCase(),
                  ),
        );
        return Scaffold(
          body: CustomScrollView(
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverAppBar(
                  backgroundColor: const Color(0xffFCCFA8),
                  floating: true,
                  snap: true,
                  toolbarHeight: 72,
                  title: TextField(
                    decoration: const InputDecoration(
                      enabledBorder: InputBorder.none,
                      border: InputBorder.none,
                      focusColor: Colors.grey,
                      fillColor: Colors.grey,
                      hoverColor: Colors.grey,
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.black,
                      ),
                    ),
                    style: const TextStyle(color: Colors.black),
                    cursorColor: Colors.black,
                    keyboardType: TextInputType.text,
                    onChanged: (value) => _query.value = value,
                    toolbarOptions: const ToolbarOptions(
                      paste: true,
                      selectAll: true,
                      copy: true,
                      cut: true,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    childAspectRatio: 3 / 1,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, index) {
                      final _channel = _channelList.elementAt(index);
                      return ElevatedButton(
                        onPressed: () async => Get.to(
                          TvPlayer(
                            url: _channel.url,
                            catalog: 1,
                          ),
                          preventDuplicates: true,
                        ),
                        child: GridTileBar(
                          leading: IconButton(
                            icon: const Icon(Icons.favorite, color: Colors.red),
                            onPressed: () async =>
                                Hive.box<Favorite>('Favorite')
                                    .put(
                                      _channel.url,
                                      Favorite(
                                        iptvOrg: _channel,
                                      ),
                                    )
                                    .whenComplete(
                                      () async =>
                                          Scaffold.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Added ${_channel.name} to Favorites',
                                          ),
                                        ),
                                      ),
                                    ),
                          ),
                          trailing: Image.network(
                            _channel?.logo ?? 'https://via.placeholder.com/100',
                            width: 100,
                            fit: BoxFit.scaleDown,
                          ),
                          title: Text(
                            _channel.name,
                            style: const TextStyle(color: Colors.black),
                          ),
                          subtitle: Text(
                            '${_channel.country.code.toUpperCase().toFlagEmoji()} ${_channel.country.name.toUpperCase()}',
                            maxLines: 2,
                            style: const TextStyle(color: Colors.black),
                          ),
                        ),
                      );
                    },
                    childCount: _channelList.length,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (err, _) => Text(
        '$err',
      ),
    );
  }
}

class TvPlayer extends StatefulHookWidget {
  const TvPlayer({@required this.url, @required this.catalog, Key key})
      : super(key: key);

  final int catalog;
  final String url;

  @override
  _TvPlayerState createState() => _TvPlayerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
      ..add(IntProperty('catalog', catalog))
      ..add(StringProperty('url', url));
  }
}

class _TvPlayerState extends State<TvPlayer> {
  VideoPlayerController _controller;

  @override
  void dispose() {
    super.dispose();
    _controller
      ..pause()
      ..dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.network(
      widget.catalog == 0
          ? widget.url.substring(0, widget.url.length - 22)
          : widget.url,
    )
      ..initialize().then((_) => setState(() {}))
      ..play();
  }

  @override
  Scaffold build(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: _controller.value.initialized
              ? AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(
                    _controller,
                  ),
                )
              : const CircularProgressIndicator(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => setState(() => _controller.value.isPlaying
              ? _controller.pause()
              : _controller.play()),
          child: Icon(
            _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          ),
        ),
      );
}

class FavoriteView extends HookWidget {
  const FavoriteView({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          IconButton(
            tooltip: 'Clear all favorites',
            icon: const Icon(Icons.clear_all),
            onPressed: () => showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text(
                  'Warning',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                content: const Text(
                  'This will remove all channels from favorites.\nThis action is irreversable.',
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
                actions: <Widget>[
                  RaisedButton(
                    color: Theme.of(context).cardColor,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Cancel',
                    ),
                  ),
                  RaisedButton(
                    color: Theme.of(context).cardColor,
                    onPressed: () async {
                      await Hive.box<Favorite>('Favorite').clear();
                      // await _bannerAd?.dispose();
                      // _bannerAd = null;
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Confirm',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ValueListenableBuilder(
          valueListenable: Hive.box<Favorite>('Favorite').listenable(),
          builder: (context, Box<Favorite> box, _) {
            if (box.isEmpty) {
              return const Text(
                'No Favorites have been added',
              );
            } else {
              return CustomScrollView(slivers: [
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 400,
                      childAspectRatio: 3 / 1,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (_, index) {
                        final _data = box.getAt(index);

                        if (_data.iptvCat != null) {
                          final _channel = _data.iptvCat;
                          return ElevatedButton(
                            onPressed: () async => Get.to(
                              TvPlayer(
                                url: _channel.link,
                                catalog: 0,
                              ),
                              preventDuplicates: true,
                            ),
                            child: GridTileBar(
                              leading: IconButton(
                                tooltip:
                                    'Remove ${_channel.channel} from Favorites',
                                icon: const Icon(Icons.delete_forever),
                                onPressed: () async => box.deleteAt(index),
                              ),
                              title: Text(
                                _channel.channel,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black),
                                maxLines: 2,
                              ),
                              subtitle: Text(
                                '${int.parse(
                                      _channel.mbps.removeSuffix(', ...'),
                                    ) / 1000} mpbs',
                                style: const TextStyle(color: Colors.black),
                              ),
                              trailing: _channel.format == 'hd'
                                  ? const Icon(
                                      Icons.hd,
                                      color: Colors.black,
                                    )
                                  : const Icon(
                                      Icons.fiber_dvr,
                                      color: Colors.black,
                                    ),
                            ),
                          );
                        } else if (_data.iptvOrg != null) {
                          final _channel = _data.iptvOrg;
                          return ElevatedButton(
                            onPressed: () async => Get.to(
                              TvPlayer(
                                url: _channel.url,
                                catalog: 1,
                              ),
                              preventDuplicates: true,
                            ),
                            child: GridTileBar(
                              leading: IconButton(
                                tooltip:
                                    'Remove ${_channel.name} from Favorites',
                                icon: const Icon(Icons.delete_forever),
                                onPressed: () async => box.deleteAt(index),
                              ),
                              trailing: Image.network(
                                _channel?.logo ??
                                    'https://via.placeholder.com/100',
                                width: 100,
                                fit: BoxFit.scaleDown,
                              ),
                              title: Text(
                                _channel.name,
                                style: const TextStyle(color: Colors.black),
                              ),
                              subtitle: Text(
                                '${_channel.country.code.toUpperCase().toFlagEmoji()} ${_channel.country.name.toUpperCase()}',
                                maxLines: 2,
                                style: const TextStyle(color: Colors.black),
                              ),
                            ),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      },
                      childCount: box.length,
                    ),
                  ),
                ),
              ]);
            }
          },
        ),
      ),
    );
  }
}
