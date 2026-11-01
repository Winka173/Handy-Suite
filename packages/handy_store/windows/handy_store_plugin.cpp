#include "handy_store_plugin.h"
#include <flutter/standard_method_codec.h>
#include <shobjidl_core.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Foundation.Collections.h>
#include <winrt/Windows.Services.Store.h>
#include <string>

namespace handy_store {
using flutter::EncodableMap;
using flutter::EncodableValue;
using Result = flutter::MethodResult<EncodableValue>;
namespace {
EncodableValue State(const std::string& product, const std::string& status, const std::string& reason = "", bool owned = false, const std::string& price = "") {
 return EncodableValue(EncodableMap{{EncodableValue("productId"),EncodableValue(product)},{EncodableValue("status"),EncodableValue(status)},{EncodableValue("reason"),EncodableValue(reason)},{EncodableValue("owned"),EncodableValue(owned)},{EncodableValue("verified"),EncodableValue(owned)},{EncodableValue("price"),EncodableValue(price)}});
}
winrt::fire_and_forget Execute(HWND window, std::string method, std::string product, std::shared_ptr<Result> reply) {
 using namespace winrt;
 using namespace Windows::Services::Store;
 try {
  auto context = StoreContext::GetDefault();
  context.as<IInitializeWithWindow>()->Initialize(window);
  auto kinds = single_threaded_vector<hstring>({L"Durable"});
  auto query = co_await context.GetAssociatedStoreProductsAsync(kinds);
  if(FAILED(query.ExtendedError())) {reply->Success(State(product,"unavailable","store_identity_or_products_unavailable"));co_return;}
  StoreProduct matched{nullptr};
  for(auto const& entry: query.Products()) {if(to_string(entry.Value().StoreId())==product && entry.Value().ProductKind()==L"Durable") {matched=entry.Value();break;}}
  if(!matched) {reply->Success(State(product,"unavailable","durable_product_unavailable"));co_return;}
  if(method=="buy") {
   auto purchase=co_await context.RequestPurchaseAsync(to_hstring(product));
   if(purchase.Status()!=StorePurchaseStatus::Succeeded && purchase.Status()!=StorePurchaseStatus::AlreadyPurchased) {
    const bool canceled=purchase.Status()==StorePurchaseStatus::NotPurchased;
    reply->Success(State(product,canceled?"canceled":"error",canceled?"":"purchase_failed"));co_return;
   }
  }
  auto license=co_await context.GetAppLicenseAsync();
  bool owned=false;
  for(auto const& sku:matched.Skus()) {
   if(sku.IsSubscription()) continue;
   for(auto const& entry:license.AddOnLicenses()) {
    auto addon=entry.Value();if(addon.IsActive() && addon.SkuStoreId()==sku.StoreId()) {owned=true;break;}
   }
  }
  reply->Success(State(product,owned?"owned":"ready","",owned,to_string(matched.Price().FormattedPrice())));
 } catch(...) {reply->Success(State(product,"unavailable","store_identity_or_connection_unavailable"));}
}
}
void HandyStorePlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
 auto channel=std::make_unique<flutter::MethodChannel<EncodableValue>>(registrar->messenger(),"handy_store",&flutter::StandardMethodCodec::GetInstance());
 auto plugin=std::make_unique<HandyStorePlugin>();
 if(registrar->GetView())plugin->window_=registrar->GetView()->GetNativeWindow();
 channel->SetMethodCallHandler([pointer=plugin.get()](const auto& call, auto result){pointer->HandleMethodCall(call,std::move(result));});
 registrar->AddPlugin(std::move(plugin));
}
HandyStorePlugin::HandyStorePlugin() = default;
HandyStorePlugin::~HandyStorePlugin() = default;
void HandyStorePlugin::HandleMethodCall(const flutter::MethodCall<EncodableValue>& call, std::unique_ptr<Result> result) {
 const auto method=call.method_name();if(method!="read" && method!="buy" && method!="restore") {result->NotImplemented();return;}
 std::string product;
 const auto* arguments=std::get_if<EncodableMap>(call.arguments());
 if(arguments) {auto it=arguments->find(EncodableValue("productId"));if(it!=arguments->end()) {if(auto value=std::get_if<std::string>(&it->second))product=*value;}}
 if(product.empty() || product.size()!=12 || product.find_first_not_of("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")!=std::string::npos || !window_) {result->Success(State(product,"unavailable","configuration_required"));return;}
 Execute(window_,method,product,std::shared_ptr<Result>(std::move(result)));
}
}  // namespace handy_store
