import 'dart:convert';
import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:handyman_admin_flutter/components/base_scaffold_widget.dart';
import 'package:handyman_admin_flutter/components/cached_image_widget.dart';
import 'package:handyman_admin_flutter/main.dart';
import 'package:handyman_admin_flutter/model/attachment_model.dart';
import 'package:handyman_admin_flutter/model/category_response.dart';
import 'package:handyman_admin_flutter/model/service_model.dart';
import 'package:handyman_admin_flutter/model/user_data.dart';
import 'package:handyman_admin_flutter/networks/network_utils.dart';
import 'package:handyman_admin_flutter/networks/rest_apis.dart';
import 'package:handyman_admin_flutter/screens/user/user_list_screen.dart';
import 'package:handyman_admin_flutter/utils/colors.dart';
import 'package:handyman_admin_flutter/utils/common.dart';
import 'package:handyman_admin_flutter/utils/constant.dart';
import 'package:handyman_admin_flutter/utils/images.dart';
import 'package:handyman_admin_flutter/utils/model_keys.dart';
import 'package:http/http.dart';
import 'package:nb_utils/nb_utils.dart';

import '../../model/provider_address_mapping_model.dart';
import '../../model/static_data_model.dart';

class AddServiceScreen extends StatefulWidget {
  final int? categoryId;
  final ServiceData? data;
  final bool isUpdate;

  AddServiceScreen({
    this.categoryId,
    this.data,
    this.isUpdate = false,
  });

  @override
  AddServiceScreenState createState() => AddServiceScreenState();
}

class AddServiceScreenState extends State<AddServiceScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  UniqueKey uniqueKeyForSubCategory = UniqueKey();

  TextEditingController serviceNameCont = TextEditingController();
  TextEditingController priceCont = TextEditingController();
  TextEditingController discountCont = TextEditingController(text: '0');
  TextEditingController descriptionCont = TextEditingController();
  TextEditingController durationContHr = TextEditingController();
  TextEditingController prePayAmountController = TextEditingController();

  ServiceData serviceDetail = ServiceData();

  //file picker
  FilePickerResult? filePickerResult;
  List<File> imageFiles = [];
  List<Attachments> eAttachments = [];

  List<int> selectedAddress = [];

  List<ProviderAddressMapping> serviceAddressList = [];

  FocusNode serviceNameFocus = FocusNode();
  FocusNode priceFocus = FocusNode();
  FocusNode discountFocus = FocusNode();
  FocusNode descriptionFocus = FocusNode();
  FocusNode durationHrFocus = FocusNode();
  FocusNode prePayAmountFocus = FocusNode();

  List<CategoryData> categoryList = [];
  List<UserData> providerList = [];

  List<StaticDataModel> typeStaticData = [
    StaticDataModel(key: SERVICE_TYPE_FREE, value: locale.free),
    StaticDataModel(key: SERVICE_TYPE_FIXED, value: locale.fixed),
    StaticDataModel(key: SERVICE_TYPE_HOURLY, value: locale.lblHourly),
  ];

  List<StaticDataModel> statusListStaticData = [
    StaticDataModel(key: ACTIVE, value: locale.active),
    StaticDataModel(key: IN_ACTIVE, value: locale.inactive),
  ];

  StaticDataModel? serviceStatusModel;

  CategoryData? selectedCategory;
  String serviceType = SERVICE_TYPE_FIXED;
  String serviceStatus = ACTIVE;

  bool afterInit = false;
  bool isFeature = false;
  int? serviceId;
  int? selectedProviderId;
  UserData? selectedProvider;

  CategoryData? selectedSubCategoryData;
  List<CategoryData> subCategoryList = [];

  bool isAdvancePaymentAllowedBySystem = getBoolAsync(IS_ADVANCE_PAYMENT_ALLOWED);
  bool isAdvancePayment = false;
  TimeOfDay? currentTime;

  @override
  void initState() {
    super.initState();

    afterBuildCreated(() {
      setStatusBarColor(context.primaryColor);
      init();
    });
  }

  Future<void> init() async {
    appStore.setLoading(true);

    //serviceType = typeStaticData[0];
    //serviceStatus = statusList[0];

    await getCategory();
    await getProviderList();

    if (widget.data != null) {
      getEditServiceData();
    }

    afterInit = true;
    //setState(() {});
  }

  Future<void> getEditServiceData() async {
    serviceDetail = widget.data!;
    serviceId = widget.data!.id;
    serviceNameCont.text = serviceDetail.name.validate();
    priceCont.text = serviceDetail.price.toString();
    discountCont.text = serviceDetail.discount.toString().validate(value: '0');
    descriptionCont.text = serviceDetail.description.validate();
    durationContHr.text = serviceDetail.duration.validate();
    isFeature = serviceDetail.isFeatured.validate() == 1 ? true : false;
    serviceStatus = serviceDetail.status == 1 ? ACTIVE : IN_ACTIVE;
    if (serviceStatus == ACTIVE) {
      serviceStatusModel = statusListStaticData.first;
    } else {
      serviceStatusModel = statusListStaticData[1];
    }
    serviceType = serviceDetail.type.validate();
    log(serviceDetail.type.validate());

    isAdvancePayment = widget.data!.isAdvancePayment;
    if (widget.data!.advancePaymentAmount != null) {
      prePayAmountController.text = widget.data!.advancePaymentAmount.validate().toString();
    }
    serviceDetail.attchments!.map((e) {
      eAttachments.add(e);
    }).toList();

    afterInit = true;
    await getUserDetail(widget.data!.providerId!).then((value) async {
      selectedProvider = value.userData!;
      selectedProviderId = selectedProvider!.id;
      await getAddressesList(selectedProviderId);
    });

    //uniqueKeyForSubCategory= UniqueKey();
    LiveStream().emit(SELECT_SUBCATEGORY, selectedCategory!.id.validate());
    setState(() {});
  }

  Future<void> getCategory() async {
    await getCategoryList(perPage: PER_PAGE_ALL, categoryList: categoryList).then((value) {
      if (widget.data != null) selectedCategory = categoryList.firstWhere((element) => element.id == widget.data!.categoryId);

      if (widget.categoryId != null && categoryList.any((element) => element.id == widget.categoryId)) {
        selectedCategory = categoryList.firstWhere((element) => element.id == widget.categoryId);
      }

      if (selectedCategory != null) {
        getSubCategory(selectedCategory!.id.validate());
      }

      setState(() {});
      appStore.setLoading(false);
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString(), print: true);
    });
  }

  Future<void> getSubCategory(int subCategory) async {
    subCategoryList.clear();

    getSubCategoryList(
      catId: subCategory.toInt().validate(),
      perPage: PER_PAGE_ITEM,
      subCategoryList: subCategoryList,
      callback: (res) {
        setState(() {});
      },
    ).then((value) {
      if (value.isNotEmpty) {
        /// logic for Sub Category Selection
        selectedSubCategoryData = value.firstWhere((element) => element.id == widget.data!.subCategoryId.validate(), orElse: null);
        setState(() {});
      }
    }).catchError(onError);
  }

  Future<void> getAddressesList(int? providerId) async {
    getProviderAddress(id: providerId!, providerAddress: serviceAddressList).then((value) {
      if (widget.data != null) {
        serviceAddressList.forEach(
          (addressElement) {
            serviceDetail.serviceAddressMapping!.forEach(
              (element) {
                if (element.providerAddressMapping!.id == addressElement.id) {
                  addressElement.isSelected = true;
                  selectedAddress.add(addressElement.id.validate());
                } else {
                  addressElement.isSelected = false;
                }
              },
            );
          },
        );
      }

      setState(() {});
      appStore.setLoading(false);
    }).catchError((e) {
      toast(e.toString(), print: true);
      appStore.setLoading(false);
    });
  }

  Future<void> getProviderList() async {
    await getUser(userType: USER_TYPE_PROVIDER, userdata: providerList).then((value) {
      appStore.setLoading(false);
      //imageFiles.add(widget.data!.imageAttachments!);

      afterInit = true;

      setState(() {});
    }).catchError((e) {
      if (!mounted) return;
      toast(e.toString(), print: true);
      appStore.setLoading(false);
    });
  }

  Future<void> getMultipleFile() async {
    filePickerResult = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['jpg', 'png', 'jpeg']);

    if (filePickerResult != null) {
      setState(() {
        imageFiles = filePickerResult!.paths.map((path) => File(path!)).toList();
      });
    } else {}
  }

  Future<void> addNewService() async {
    hideKeyboard(context);

    // Check if image is selected when adding new service
    if (serviceId == null && imageFiles.isEmpty) {
      return toast(locale.chooseAtLeastOneImage);
    }

    MultipartRequest multiPartRequest = await getMultiPartRequest('service-save');

    if (serviceId != null) {
      multiPartRequest.fields[CommonKeys.id] = serviceId.toString();
    }

    multiPartRequest.fields[AddServiceKey.name] = serviceNameCont.text.validate();
    multiPartRequest.fields[AddServiceKey.providerId] = selectedProviderId.validate().toString();
    multiPartRequest.fields[AddServiceKey.categoryId] = selectedCategory!.id.toString();
    if (selectedSubCategoryData != null) multiPartRequest.fields[AddServiceKey.subCategoryId] = selectedSubCategoryData!.id.toString();
    multiPartRequest.fields[AddServiceKey.type] = serviceType.validate();
    multiPartRequest.fields[AddServiceKey.price] = priceCont.text.toString();
    multiPartRequest.fields[AddServiceKey.discountPrice] = discountCont.text.toString().validate();
    multiPartRequest.fields[AddServiceKey.description] = descriptionCont.text.validate();
    multiPartRequest.fields[AddServiceKey.isFeatured] = isFeature ? '1' : '0';
    multiPartRequest.fields[AddServiceKey.status] = serviceStatus.validate() == ACTIVE ? '1' : '0';

    multiPartRequest.fields[AddServiceKey.duration] = durationContHr.text.toString().validate();

    for (int i = 0; i < selectedAddress.length; i++) {
      multiPartRequest.fields[AddServiceKey.providerAddressId + '[$i]'] = selectedAddress[i].toString().validate();
    }

    log('multiPartRequest.fields : ${multiPartRequest.fields}');

    log(serviceType.validate());
    if (imageFiles.isNotEmpty) {
      await Future.forEach<File>(imageFiles, (element) async {
        int i = imageFiles.indexOf(element);

        multiPartRequest.files.add(await MultipartFile.fromPath('${AddServiceKey.serviceAttachment + i.toString()}', element.path));
      });
    }

    if (isAdvancePaymentAllowedBySystem && isAdvancePayment) {
      multiPartRequest.fields[AdvancePaymentKey.isEnableAdvancePayment] = isAdvancePayment ? '1' : "0";
      multiPartRequest.fields[AdvancePaymentKey.advancePaymentAmount] = prePayAmountController.text.validate().toDouble().toString();
    }

    if (imageFiles.isNotEmpty) multiPartRequest.fields[AddServiceKey.attachmentCount] = imageFiles.length.toString();

    multiPartRequest.headers.addAll(buildHeaderTokens());

    appStore.setLoading(true);
    sendMultiPartRequest(
      multiPartRequest,
      onSuccess: (data) async {
        appStore.setLoading(false);
        toast(jsonDecode(data)['message'], print: true);

        finish(context, true);
      },
      onError: (error) {
        toast(error.toString(), print: true);
        appStore.setLoading(false);
      },
    ).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString());
    });
  }

  void checkValidation() {
    if (imageFiles.isEmpty && eAttachments.isEmpty) {
      return toast(locale.chooseAtLeastOneImage);
    }

    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      hideKeyboard(context);

      if (selectedCategory == null) {
        toast(locale.pleaseSelectedCategory);
      } else if (selectedProvider == null) {
        toast(locale.pleaseSelectAProvider);
      } else if (selectedAddress.isEmpty) {
        toast(locale.pleaseSelectServiceAddress);
      } else {
        addNewService();
      }
    }
  }

  Future<void> removeAttachment({required int id, required int index}) async {
    showConfirmDialogCustom(context, dialogType: DialogType.DELETE, onAccept: (_) async {
      appStore.setLoading(true);

      Map req = {
        "type": 'service_attachment',
        CommonKeys.id: id,
      };

      await deleteImage(req).then((value) {
        eAttachments.removeAt(index.validate());
        setState(() {});

        appStore.setLoading(false);
        toast(value.message.validate(), print: true);
      }).catchError((e) {
        appStore.setLoading(false);
        toast(e.toString(), print: true);
      });
    });
  }

  void pickProvider() async {
    UserData? user = await UserListScreen(type: USER_TYPE_PROVIDER, pickUser: true).launch(context);

    if (user != null) {
      selectedProvider = user;
      selectedProviderId = user.id.validate();

      serviceAddressList.clear();
      await getAddressesList(selectedProviderId);
      setState(() {});
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    super.dispose();
    setStatusBarColor(primaryColor);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBarTitle: widget.data != null ? locale.editService : locale.addService,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: context.width(),
              height: 120,
              child: DottedBorder(
                color: primaryColor.withOpacity(0.6),
                strokeWidth: 1,
                borderType: BorderType.RRect,
                dashPattern: [6, 5],
                radius: Radius.circular(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(selectImage, height: 25, width: 25, color: appStore.isDarkMode ? white : gray),
                    8.height,
                    Text(locale.chooseImage, style: boldTextStyle()),
                  ],
                ).center().onTap(borderRadius: radius(), () async {
                  getMultipleFile();
                }),
              ),
            ),
            8.height,
            Text(locale.noteYouCanUpload, style: secondaryTextStyle(size: 8)),
            16.height,
            HorizontalList(
              itemCount: imageFiles.length,
              itemBuilder: (context, i) {
                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Image.file(imageFiles[i], width: 90, height: 90, fit: BoxFit.cover),
                    Container(
                      decoration: boxDecorationWithRoundedCorners(boxShape: BoxShape.circle, backgroundColor: primaryColor),
                      margin: EdgeInsets.only(right: 8, top: 8),
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: white),
                    ).onTap(() {
                      imageFiles.removeAt(i);
                      setState(() {});
                    }),
                  ],
                );
              },
            ).paddingBottom(16).visible(imageFiles.isNotEmpty),
            HorizontalList(
              itemCount: eAttachments.length,
              itemBuilder: (context, i) {
                return Stack(
                  alignment: Alignment.topRight,
                  children: [
                    CachedImageWidget(
                      url: eAttachments[i].url.validate(),
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                    Container(
                      decoration: boxDecorationWithRoundedCorners(boxShape: BoxShape.circle, backgroundColor: primaryColor),
                      margin: EdgeInsets.only(right: 8, top: 8),
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 16, color: white),
                    ).onTap(() {
                      removeAttachment(id: eAttachments[i].id!, index: i);
                    })
                  ],
                );
              },
            ).paddingBottom(16).visible(eAttachments.isNotEmpty),
            8.height,
            Container(
              decoration: boxDecorationWithRoundedCorners(
                borderRadius: radius(),
                backgroundColor: appStore.isDarkMode ? cardDarkColor : cardColor,
              ),
              padding: EdgeInsets.all(16),
              child: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      textFieldType: TextFieldType.NAME,
                      controller: serviceNameCont,
                      focus: serviceNameFocus,
                      nextFocus: priceFocus,
                      errorThisFieldRequired: locale.thisFieldIsRequired,
                      decoration: inputDecoration(context, hint: locale.serviceName, fillColor: context.scaffoldBackgroundColor),
                    ),
                    16.height,
                    DropdownButtonFormField<CategoryData>(
                      decoration: inputDecoration(context, fillColor: context.scaffoldBackgroundColor, hint: locale.category),
                      value: selectedCategory,
                      dropdownColor: context.scaffoldBackgroundColor,
                      hint: Text(locale.selectCategory, style: secondaryTextStyle()),
                      items: categoryList.map((data) {
                        return DropdownMenuItem<CategoryData>(
                          value: data,
                          child: Text(data.name.validate(), style: primaryTextStyle()),
                        );
                      }).toList(),
                      onChanged: (CategoryData? value) async {
                        selectedCategory = value!;
                        setState(() {});
                        LiveStream().emit(SELECT_SUBCATEGORY, selectedCategory!.id.validate());
                        subCategoryList.clear();

                        getSubCategoryList(
                          catId: selectedCategory!.id.validate(),
                          perPage: PER_PAGE_ITEM,
                          subCategoryList: subCategoryList,
                          callback: (res) {
                            setState(() {});
                          },
                        ).then((value) {
                          if (selectedCategory == null) {
                            if (widget.isUpdate && value.isNotEmpty) {
                              /// logic for Sub Category Selection
                              selectedCategory = value.firstWhere((element) => element.id == widget.categoryId, orElse: null);
                              setState(() {});
                            }
                          }
                        });
                      },
                    ),
                    16.height,
                    DropdownButtonFormField<CategoryData>(
                      onChanged: (CategoryData? val) {
                        selectedSubCategoryData = val;
                      },
                      value: selectedSubCategoryData,
                      dropdownColor: context.cardColor,
                      decoration: inputDecoration(context, fillColor: context.scaffoldBackgroundColor, hint: locale.subCategory),
                      hint: Text(locale.selectSubcategory, style: secondaryTextStyle()),
                      items: List.generate(
                        subCategoryList.length,
                        (index) {
                          CategoryData data = subCategoryList[index];
                          return DropdownMenuItem<CategoryData>(
                            child: Text(data.name.toString(), style: primaryTextStyle()),
                            value: data,
                          );
                        },
                      ),
                    ),
                    16.height,
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (selectedProvider != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(locale.selectedProvider, style: secondaryTextStyle()).paddingOnly(bottom: 8),
                              Row(
                                children: [
                                  CachedImageWidget(url: selectedProvider!.profileImage.validate(), height: 24, circle: true),
                                  8.width,
                                  Text(
                                    selectedProvider!.displayName.validate(),
                                    style: primaryTextStyle(size: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ).expand(),
                        TextButton(
                          onPressed: () async {
                            pickProvider();
                          },
                          child: Text(locale.pickAProvider),
                        ),
                      ],
                    ),
                    16.height,
                    Text(locale.serviceAddresses, style: secondaryTextStyle(size: 12)),
                    8.height,
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: radius(),
                        color: context.scaffoldBackgroundColor,
                      ),
                      child: ExpansionTile(
                        iconColor: context.iconColor,
                        title: Text(locale.selectServiceAddresses, style: secondaryTextStyle()),
                        trailing: Icon(Icons.arrow_drop_down),
                        children: <Widget>[
                          ListView.builder(
                            physics: NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            itemCount: serviceAddressList.length,
                            itemBuilder: (BuildContext context, int index) {
                              return Container(
                                margin: EdgeInsets.only(bottom: 8.0),
                                child: CheckboxListTile(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16),
                                  title: Text(
                                    serviceAddressList[index].address.validate(),
                                    style: secondaryTextStyle(color: context.iconColor),
                                  ),
                                  autofocus: false,
                                  activeColor: primaryColor,
                                  checkColor: context.cardColor,
                                  value: selectedAddress.contains(serviceAddressList[index].id),
                                  onChanged: (bool? val) {
                                    if (selectedAddress.contains(serviceAddressList[index].id)) {
                                      selectedAddress.remove(serviceAddressList[index].id);
                                    } else {
                                      selectedAddress.add(serviceAddressList[index].id.validate());
                                    }
                                    setState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    16.height,
                    Row(
                      children: [
                        DropdownButtonFormField<StaticDataModel>(
                          decoration: inputDecoration(
                            context,
                            fillColor: context.scaffoldBackgroundColor,
                            hint: locale.type,
                          ),
                          isExpanded: true,
                          hint: Text(locale.selectType, style: secondaryTextStyle()),
                          value: serviceType.isNotEmpty ? getServiceType : null,
                          dropdownColor: context.cardColor,
                          items: typeStaticData.map((StaticDataModel data) {
                            return DropdownMenuItem<StaticDataModel>(
                              value: data,
                              child: Text(data.value.validate(), style: primaryTextStyle()),
                            );
                          }).toList(),
                          onChanged: (StaticDataModel? value) async {
                            serviceType = value!.key.validate();

                            if (serviceType == SERVICE_TYPE_FREE) {
                              priceCont.text = '0';
                            } else if (widget.data != null) {
                              priceCont.text = widget.data!.price.validate().toString();
                            }
                            setState(() {});
                          },
                          validator: (value) {
                            if (value == null) return errorThisFieldRequired;
                            return null;
                          },
                        ).expand(flex: 1),
                        16.width,
                        DropdownButtonFormField<StaticDataModel>(
                          decoration: inputDecoration(
                            context,
                            fillColor: context.scaffoldBackgroundColor,
                            hint: locale.status,
                          ),
                          isExpanded: true,
                          hint: Text(locale.selectStatus, style: secondaryTextStyle()),
                          dropdownColor: context.cardColor,
                          value: serviceStatusModel != null ? serviceStatusModel : statusListStaticData.first,
                          items: statusListStaticData.map((StaticDataModel data) {
                            return DropdownMenuItem<StaticDataModel>(
                              value: data,
                              child: Text(data.value.validate(), style: primaryTextStyle()),
                            );
                          }).toList(),
                          onChanged: (StaticDataModel? value) async {
                            serviceStatus = value!.key.validate();
                            setState(() {});
                          },
                          validator: (value) {
                            if (value == null) return errorThisFieldRequired;
                            return null;
                          },
                        ).expand(flex: 1),
                      ],
                    ),
                    24.height,
                    Row(
                      children: [
                        AppTextField(
                          textFieldType: TextFieldType.PHONE,
                          controller: priceCont,
                          focus: priceFocus,
                          nextFocus: discountFocus,
                          enabled: serviceType != SERVICE_TYPE_FREE,
                          errorThisFieldRequired: locale.thisFieldIsRequired,
                          decoration: inputDecoration(
                            context,
                            hint: locale.price,
                            fillColor: context.scaffoldBackgroundColor,
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (s) {
                            if (s!.isEmpty) return errorThisFieldRequired;

                            if (s.toDouble() <= 0 && serviceType != SERVICE_TYPE_FREE) return locale.priceAmountValidationMessage;
                            return null;
                          },
                        ).expand(),
                        16.width,
                        AppTextField(
                          textFieldType: TextFieldType.PHONE,
                          controller: discountCont,
                          focus: discountFocus,
                          nextFocus: durationHrFocus,
                          enabled: serviceType != SERVICE_TYPE_FREE,
                          errorThisFieldRequired: locale.thisFieldIsRequired,
                          decoration: inputDecoration(
                            context,
                            hint: locale.discount.capitalizeFirstLetter(),
                            fillColor: context.scaffoldBackgroundColor,
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (s) {
                            if (s!.isEmpty) return errorThisFieldRequired;

                            if (s.toDouble().isNegative || s.toInt() > 99) return '${discountCont.text}% ${locale.isNotValid}';
                            return null;
                          },
                        ).expand(),
                      ],
                    ),
                    24.height,
                    AppTextField(
                      textFieldType: TextFieldType.PHONE,
                      controller: durationContHr,
                      focus: durationHrFocus,
                      nextFocus: descriptionFocus,
                      //maxLength: 2,
                      readOnly: true,
                      errorThisFieldRequired: locale.thisFieldIsRequired,
                      onTap: () async {
                        currentTime = await showTimePicker(
                          context: context,
                          initialTime: currentTime ?? TimeOfDay.now(),
                          helpText: locale.selectDuration,
                        );

                        if (currentTime != null) {
                          durationContHr.text = "${currentTime!.hour}:${currentTime!.minute}";
                        }
                      },
                      decoration: inputDecoration(
                        context,
                        hint: locale.duration,
                        fillColor: context.scaffoldBackgroundColor,
                        counterText: '',
                      ),
                    ),
                    /*Row(
                      children: [
                        AppTextField(
                          textFieldType: TextFieldType.PHONE,
                          controller: durationContHr,
                          focus: durationHrFocus,
                          nextFocus: durationMinFocus,
                          maxLength: 2,
                          errorThisFieldRequired: locale.thisFieldIsRequired,
                          decoration: inputDecoration(
                            context,
                            hint: locale.durationHours,
                            fillColor: context.scaffoldBackgroundColor,
                            counterText: '',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (s) {
                            //if (s!.isEmpty) return errorThisFieldRequired;

                            if (s.toInt() > 24) return locale.enterHoursUpTo24Hours;
                            //if (s.toInt() == 0) return errorThisFieldRequired;
                            return null;
                          },
                        ).paddingRight(8).expand(),
                        AppTextField(
                          textFieldType: TextFieldType.PHONE,
                          controller: durationContMin,
                          focus: durationMinFocus,
                          nextFocus: descriptionFocus,
                          maxLength: 2,
                          errorThisFieldRequired: locale.thisFieldIsRequired,
                          decoration: inputDecoration(
                            context,
                            hint: locale.durationMinute,
                            fillColor: context.scaffoldBackgroundColor,
                            counterText: '',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (s) {
                            if (s!.isEmpty) return errorThisFieldRequired;

                            if (s.toInt() > 60) return locale.enterMinuteUpTo60Minute;
                            return null;
                          },
                        ).expand(),
                      ],
                    ),*/
                    24.height,
                    AppTextField(
                      textFieldType: TextFieldType.MULTILINE,
                      minLines: 5,
                      controller: descriptionCont,
                      focus: descriptionFocus,
                      errorThisFieldRequired: locale.thisFieldIsRequired,
                      decoration: inputDecoration(
                        context,
                        hint: locale.description,
                        fillColor: context.scaffoldBackgroundColor,
                      ),
                    ),
                    8.height,
                    CheckboxListTile(
                      value: isFeature,
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: radius(50), side: BorderSide(color: primaryColor)),
                      title: Text(locale.setAsFeature, style: secondaryTextStyle()),
                      onChanged: (bool? v) {
                        isFeature = v.validate();
                        setState(() {});
                      },
                    ),
                    8.height,
                    if (isAdvancePaymentAllowedBySystem && serviceType == SERVICE_TYPE_FIXED)
                      Container(
                        decoration: boxDecorationDefault(color: context.scaffoldBackgroundColor, borderRadius: radius()),
                        child: SettingItemWidget(
                          title: locale.enablePrePayment,
                          subTitle: locale.enablePrePaymentMessage,
                          trailing: CupertinoSwitch(
                            activeColor: primaryColor,
                            value: isAdvancePayment,
                            onChanged: (v) async {
                              isAdvancePayment = !isAdvancePayment;
                              setState(() {});
                            },
                          ),
                        ),
                      ),
                    16.height,
                    if (isAdvancePaymentAllowedBySystem && isAdvancePayment)
                      AppTextField(
                        textFieldType: TextFieldType.PHONE,
                        controller: prePayAmountController,
                        focus: prePayAmountFocus,
                        maxLength: 3,
                        errorThisFieldRequired: locale.thisFieldIsRequired,
                        decoration: inputDecoration(
                          context,
                          hint: locale.advancePayAmountPer,
                          //hint: locale.advancePayAmountPer,
                          fillColor: context.scaffoldBackgroundColor,
                          counterText: '',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (s) {
                          if (s!.isEmpty) return errorThisFieldRequired;

                          if (s.toInt() <= 0 || s.toInt() >= 100) return locale.valueConditionMessage;
                          //if (s.toInt() <= 0 || s.toInt() >= 100) return locale.valueConditionMessage;
                          return null;
                        },
                      ),
                  ],
                ),
              ),
            ),
            24.height,
            AppButton(
              text: locale.save,
              color: primaryColor,
              width: context.width(),
              onTap: () {
                ifNotTester(context, () {
                  checkValidation();
                });
              },
            ),
            16.height,
          ],
        ).paddingAll(16),
      ),
    );
  }

  StaticDataModel get getServiceType => serviceType == SERVICE_TYPE_FREE
      ? typeStaticData[0]
      : serviceType == SERVICE_TYPE_FIXED
          ? typeStaticData[1]
          : typeStaticData[2];
}
