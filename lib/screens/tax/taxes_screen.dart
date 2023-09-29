import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:handyman_admin_flutter/screens/tax/add_tax_screen.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../components/app_widgets.dart';
import '../../components/base_scaffold_widget.dart';
import '../../components/empty_error_state_widget.dart';
import '../../main.dart';
import '../../model/tax_list_response.dart';
import '../../networks/rest_apis.dart';
import '../../utils/common.dart';
import '../../utils/constant.dart';

class TaxesScreen extends StatefulWidget {
  @override
  _TaxesScreenState createState() => _TaxesScreenState();
}

class _TaxesScreenState extends State<TaxesScreen> {
  Future<List<TaxData>>? future;
  List<TaxData> taxList = [];

  int page = 1;
  bool isLastPage = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    future = getTaxList(
      page: page,
      list: taxList,
      lastPageCallback: (b) {
        isLastPage = b;
      },
    );
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBarTitle: locale.taxes,
      actions: [
        IconButton(
          icon: Icon(Icons.add, color: white),
          onPressed: () async {
            bool? res = await AddTaxScreen().launch(context);

            if (res ?? false) {
              page = 1;
              init();
              setState(() {});
            }
          },
        ),
      ],
      child: Stack(
        children: [
          SnapHelperWidget<List<TaxData>>(
            future: future,
            onSuccess: (list) {
              return AnimatedListView(
                physics: AlwaysScrollableScrollPhysics(),
                itemCount: list.length,
                padding: EdgeInsets.all(8),
                disposeScrollController: false,
                shrinkWrap: true,
                listAnimationType: ListAnimationType.FadeIn,
                fadeInConfiguration: FadeInConfiguration(duration: 2.seconds),
                itemBuilder: (context, index) {
                  TaxData data = list[index];

                  return Container(
                    padding: EdgeInsets.all(16),
                    margin: EdgeInsets.all(8),
                    decoration: boxDecorationWithRoundedCorners(
                      borderRadius: radius(),
                      backgroundColor: context.cardColor,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(locale.taxName, style: secondaryTextStyle(size: 14)),
                            Text('${data.title.validate()}', style: boldTextStyle()),
                          ],
                        ),
                        8.height,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(locale.myTax, style: secondaryTextStyle(size: 14)),
                            Row(
                              children: [
                                Text(
                                  isTaxTypePercent(data.type) ? ' ${data.value.toString()} %' : ' ${getStringAsync(CURRENCY_COUNTRY_SYMBOL)}${data.value.toString()}',
                                  style: boldTextStyle(),
                                ),
                                Text(' (${data.type.capitalizeFirstLetter()})', style: boldTextStyle()),
                              ],
                            )
                          ],
                        ),
                      ],
                    ),
                  ).onTap(
                    () async {
                      bool? res = await AddTaxScreen(data: data).launch(context);
                      if (res ?? false) {
                        page = 1;
                        init();
                        setState(() {});
                      }
                    },
                    hoverColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    splashColor: Colors.transparent,
                  );
                },
                emptyWidget: NoDataWidget(
                  title: locale.noTaxesFound,
                  imageWidget: EmptyStateWidget(),
                ),
                onNextPage: () {
                  if (!isLastPage) {
                    page++;
                    appStore.setLoading(true);

                    init();
                    setState(() {});
                  }
                },
                onSwipeRefresh: () async {
                  page = 1;

                  init();
                  setState(() {});

                  return await 2.seconds.delay;
                },
              );
            },
            loadingWidget: LoaderWidget(),
            errorBuilder: (error) {
              return NoDataWidget(
                title: error,
                imageWidget: ErrorStateWidget(),
                retryText: locale.reload,
                onRetry: () {
                  page = 1;
                  appStore.setLoading(true);

                  init();
                  setState(() {});
                },
              );
            },
          ),
          Observer(builder: (context) => LoaderWidget().visible(appStore.isLoading)),
        ],
      ),
    );
  }
}
