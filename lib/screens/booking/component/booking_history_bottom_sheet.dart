import 'package:flutter/material.dart';
import 'package:handyman_admin_flutter/main.dart';
import 'package:handyman_admin_flutter/model/booking_detail_response.dart';
import 'package:handyman_admin_flutter/screens/booking/component/booking_history_list_widget.dart';
import 'package:handyman_admin_flutter/utils/colors.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../../utils/constant.dart';

class BookingHistoryBottomSheet extends StatefulWidget {
  final List<BookingActivity> data;
  final ScrollController? scrollController;

  BookingHistoryBottomSheet({required this.data, this.scrollController});

  @override
  BookingHistoryBottomSheetState createState() => BookingHistoryBottomSheetState();
}

class BookingHistoryBottomSheetState extends State<BookingHistoryBottomSheet> {
  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    //
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: boxDecorationWithRoundedCorners(borderRadius: radius(defaultRadius), backgroundColor: context.cardColor),
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        controller: widget.scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            8.height,
            Container(width: 40, height: 2, color: gray.withOpacity(0.3)).center(),
            24.height,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(locale.bookingHistory, style: boldTextStyle(size: LABEL_TEXT_SIZE)),
                Row(
                  children: [
                    Text('${locale.id}:', style: boldTextStyle(color: primaryColor, size: LABEL_TEXT_SIZE)),
                    4.width,
                    Text(
                      ' #' + widget.data[0].bookingId.toString().validate(),
                      style: boldTextStyle(color: primaryColor, size: LABEL_TEXT_SIZE),
                    ),
                  ],
                )
              ],
            ),
            16.height,
            Divider(color: context.dividerColor),
            16.height,
            if (widget.data.isNotEmpty)
              ListView.builder(
                physics: NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: widget.data.length,
                itemBuilder: (_, i) {
                  return BookingHistoryListWidget(
                    data: widget.data[i],
                    index: i,
                    length: widget.data.length.validate(),
                  );
                },
              ),
            if (widget.data.isEmpty) Text(locale.noDataFound),
          ],
        ),
      ),
    );
  }
}
