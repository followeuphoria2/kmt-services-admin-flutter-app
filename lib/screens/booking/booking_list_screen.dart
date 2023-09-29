import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:handyman_admin_flutter/components/app_widgets.dart';
import 'package:handyman_admin_flutter/components/base_scaffold_widget.dart';
import 'package:handyman_admin_flutter/components/empty_error_state_widget.dart';
import 'package:handyman_admin_flutter/main.dart';
import 'package:handyman_admin_flutter/model/booking_data_model.dart';
import 'package:handyman_admin_flutter/model/booking_status_response.dart';
import 'package:handyman_admin_flutter/networks/rest_apis.dart';
import 'package:handyman_admin_flutter/screens/booking/component/booking_item_component.dart';
import 'package:handyman_admin_flutter/screens/booking/component/status_dropdown_component.dart';
import 'package:handyman_admin_flutter/utils/constant.dart';
import 'package:nb_utils/nb_utils.dart';

class BookingListScreen extends StatefulWidget {
  final String? statusType;

  BookingListScreen({this.statusType});

  @override
  _BookingListScreenState createState() => _BookingListScreenState();
}

class _BookingListScreenState extends State<BookingListScreen> {
  ScrollController scrollController = ScrollController();

  Future<List<BookingData>>? future;
  List<BookingData> bookings = [];

  bool isLastPage = false;

  String selectedValue = BOOKING_TYPE_ALL;
  int currentPage = 1;

  @override
  void initState() {
    super.initState();
    init();

    afterBuildCreated(() {
      if (appStore.isLoggedIn) {
        setStatusBarColor(context.primaryColor);
      }
    });

    LiveStream().on(LIVESTREAM_UPDATE_BOOKING_LIST, (p0) {
      currentPage = 1;
      init();
    });
  }

  void init() async {
    if (widget.statusType.validate().isNotEmpty) {
      selectedValue = widget.statusType.validate();
    }

    fetchAllBookingList(loading: true);
  }

  Future<void> fetchAllBookingList({bool loading = true}) async {
    future = getBookingList(currentPage, status: selectedValue, bookings: bookings, lastPageCallback: (b) {
      isLastPage = b;
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBarTitle: locale.bookings,
      child: Stack(
        children: [
          SnapHelperWidget<List<BookingData>>(
            future: future,
            loadingWidget: LoaderWidget(),
            onSuccess: (list) {
              return SizedBox(
                width: context.width(),
                height: context.height(),
                child: AnimatedListView(
                  controller: scrollController,
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.only(bottom: 60, top: 8, right: 16, left: 16),
                  itemCount: list.length,
                  shrinkWrap: true,
                  listAnimationType: ListAnimationType.Slide,
                  slideConfiguration: SlideConfiguration(verticalOffset: 400),
                  disposeScrollController: false,
                  itemBuilder: (_, index) {
                    BookingData? data = list[index];

                    return GestureDetector(
                      onTap: () {
                        // BookingDetailScreen(bookingId: data.id.validate()).launch(context);
                      },
                      child: BookingItemComponent(bookingData: data),
                    );
                  },
                  emptyWidget: NoDataWidget(
                    title: locale.noBookingFound,
                    subTitle: locale.noBookingSubTitle,
                    imageWidget: EmptyStateWidget(),
                  ),
                  onNextPage: () {
                    if (!isLastPage) {
                      currentPage++;
                      appStore.setLoading(true);

                      init();
                      setState(() {});
                    }
                  },
                  onSwipeRefresh: () async {
                    currentPage = 1;

                    init();
                    setState(() {});

                    return await 2.seconds.delay;
                  },
                ).paddingOnly(left: 0, right: 0, bottom: 0, top: 76),
              );
            },
            errorBuilder: (error) {
              return NoDataWidget(
                title: error,
                imageWidget: ErrorStateWidget(),
                retryText: locale.reload,
                onRetry: () {
                  currentPage = 1;
                  appStore.setLoading(true);

                  init();
                  setState(() {});
                },
              );
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: StatusDropdownComponent(
              isValidate: false,
              onValueChanged: (BookingStatusResponse value) {
                currentPage = 1;
                appStore.setLoading(true);

                selectedValue = value.value.validate(value: BOOKING_PAYMENT_STATUS_ALL);
                fetchAllBookingList(loading: true);
                setState(() {});

                if (bookings.isNotEmpty) {
                  scrollController.animateTo(0, duration: 1.seconds, curve: Curves.easeOutQuart);
                } else {
                  scrollController = ScrollController();
                }
              },
            ),
          ),
          Observer(
            builder: (context) => LoaderWidget().visible(appStore.isLoading),
          ),
        ],
      ),
    );
  }
}
