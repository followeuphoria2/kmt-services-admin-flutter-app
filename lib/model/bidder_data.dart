import 'package:handyman_admin_flutter/model/post_job_data.dart';
import 'package:handyman_admin_flutter/model/user_data.dart';

class BidderData {
  num? id;
  num? postRequestId;
  num? providerId;
  num? price;
  String? duration;
  UserData? provider;
  PostJobData? postJobData;

  BidderData({
    this.id,
    this.postRequestId,
    this.providerId,
    this.price,
    this.duration,
    this.provider,
    this.postJobData,
  });

  BidderData.fromJson(dynamic json) {
    id = json['id'];
    postRequestId = json['post_request_id'];
    providerId = json['provider_id'];
    price = json['price'];
    duration = json['duration'];
    provider = json['provider'] != null ? UserData.fromJson(json['provider']) : null;
    postJobData = json['post_detail'] != null ? PostJobData.fromJson(json['post_detail']) : null;
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['id'] = id;
    map['post_request_id'] = postRequestId;
    map['provider_id'] = providerId;
    map['price'] = price;
    map['duration'] = duration;
    if (provider != null) {
      map['provider'] = provider?.toJson();
    }
    if (postJobData != null) {
      map['post_detail'] = postJobData?.toJson();
    }
    return map;
  }
}
