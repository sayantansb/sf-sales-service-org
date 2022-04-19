/**
 * Created by sayantan.sb on 19.04.22.
 */

global with sharing class BookingInvoker {

    @future(callout=true)
    public static void invokeBookingAsync(List<Id> opportunityIds) {
        invokePostStatusChangedBooking(opportunityIds);
    }

    public static void invokePostStatusChangedBooking(List<Id> opportunityIds) {

        List<Opportunity> opportunities = [SELECT Id, AgreementForm__c,DealType__c,RequestorId__c,AccountId FROM Opportunity WHERE Id IN :opportunityIds];

        List<Id> accountIds = new List<Id>();
        for (Opportunity opportunity : opportunities) {
            accountIds.add(opportunity.AccountId);
        }
        List<Account> accounts = [SELECT Id, Name,OwnerId,ClearingHouse__c, LiableOffice__c, SalesTeam__c,BookingType__c,BillingTerms__c,SalesChannel__c,AccessType__c FROM Account WHERE Id IN :accountIds];
        Map<Id, Account> accountById = new Map<Id, Account>();
        for (Account account : accounts) {
            accountById.put(account.Id, account);
        }

        List<Contact> userContacts = [SELECT Id,FirstName,LastName,Gender__c,AccountId,Phone,Email,MailingCountry,MailingCity,MailingPostalCode,MailingStreet,HouseNumber__c FROM Contact WHERE AccountId IN :accountIds];
        Map<Id,Contact> contactsByAccountId = new Map<Id, Contact>();
        for(Contact contact: userContacts){
            contactsByAccountId.put(contact.AccountId,Contact);
        }

        List<FeatureProduct__c> featureProducts = [SELECT Id,Type__c,Price__c,PricePerMonth__c,description__c,Opportunity__c FROM FeatureProduct__c WHERE Opportunity__c IN :opportunityIds];
        Map<Id,List<FeatureProduct__c>> featureProductsByOppId = new Map<Id, List<FeatureProduct__c>>();
        for(FeatureProduct__c featureProduct : featureProducts){
            if(featureProductsByOppId.containsKey(featureProduct.Opportunity__c)){
                featureProductsByOppId.get(featureProduct.Opportunity__c).add(featureProduct);
            }else{
                List<FeatureProduct__c> featureProductList = new List<FeatureProduct__c>();
                featureProductList.add(featureProduct);
                featureProductsByOppId.put(featureProduct.Opportunity__c,featureProductList);
            }
        }

        List<RevenueShare__c> revenueShares = [SELECT Id,Opportunity__c,TotalShareValue__c,TotalShareInPercent__c,SalesManagerId__c,ProfitCenter__c FROM RevenueShare__c WHERE Opportunity__c IN :opportunityIds];
        Map<Id,List<RevenueShare__c>> revenueSharesByOppId = new Map<Id, List<RevenueShare__c>>();
        for(RevenueShare__c revenueShare:revenueShares ){
            if(revenueSharesByOppId.containsKey(revenueShare.Opportunity__c)){
                revenueSharesByOppId.get(revenueShare.Opportunity__c).add(revenueShare);
            }else{
                List<RevenueShare__c> revenueShareList = new List<RevenueShare__c>();
                revenueShareList.add(revenueShare);
                revenueSharesByOppId.put(revenueShare.Opportunity__c,revenueShareList);
            }
        }

        Map<Id, Contact> contactsByOpportunityId = new Map<Id, Contact>();
        Map<Id, Account> accountByOpportunityId = new Map<Id, Account>();
        for (Opportunity opportunity : opportunities) {
            accountByOpportunityId.put(opportunity.Id, accountById.get(opportunity.AccountId));
            contactsByOpportunityId.put(opportunity.Id, contactsByAccountId.get(opportunity.AccountId));
        }

        for (Opportunity opportunity : opportunities) {
            try {
                BookingRequest bookingRequest = createBookingRequest(opportunity);
                Account account = accountByOpportunityId.get(opportunity.Id);
                Contact contact = contactsByOpportunityId.get(opportunity.Id);
                fillAccountContact(bookingRequest, account, contact,opportunity.Id);
                fillFeatureProductList(bookingRequest,featureProductsByOppId.get(opportunity.Id),opportunity.Id);
                fillRevenueShareList(bookingRequest,revenueSharesByOppId.get(opportunity.Id),opportunity.Id);
                //This is the limitation of this approach
                // The API only accepts Booking Request for one Opportunity at a time
                //So API invocation will happen in loop if Opportunities are Closed in Bulk with batch
                //For this reason the trigger has been configured to not work for batch
                Integer bookingId = invokeBookingAPI(bookingRequest);
                if(bookingId>-1){
                    LogUtil.insertDebugEvent('Successfully Created BookingRequest on Opportunity Stage Closed WON','Opportunity',opportunity.id,'Booking Request Creation Successful, bookingId = '+bookingId,'DEBUG');
                }else{
                    LogUtil.insertDebugEvent('BookingRequest Invocation Failed on Opportunity Stage Closed WON','Opportunity',opportunity.id,'Error in Booking API Invocation','ERROR');
                }


            } catch(Exception e) {
                LogUtil.insertDebugEvent('BookingRequest Invocation on Opportunity Stage Closed WON','Opportunity',opportunity.id,e.getMessage(),'ERROR');
                System.debug('Error on BookingRequest Invocation on Opportunity Stage Closed WON, opportunityId=' + opportunity.id + '. StackTrace: ' + e.getStackTraceString());
            }
        }


    }

    @TestVisible
    private static BookingRequest createBookingRequest(Opportunity opportunity) {
        BookingRequest bookingRequest = new BookingRequest();
        RequestEntry request = new RequestEntry();
        request.salesforceOpportunityId = opportunity.Id;
        request.agreementForm = opportunity.AgreementForm__c;
        request.dealType = opportunity.DealType__c;
        request.requesterId = Integer.valueOf(opportunity.RequestorId__c);
        bookingRequest.request = request;
        return bookingRequest;
    }

    @TestVisible
    public static void fillAccountContact(BookingRequest bookingRequest, Account account, Contact mainContact,Id opportunityId) {
        System.debug('Before fillAccountContactAndLead AccountId: '+account.Id);
        UserContactAddress userContactAddress = new UserContactAddress();
        try {
            userContactAddress.firstname = mainContact.FirstName;
            userContactAddress.lastname = mainContact.LastName;
            userContactAddress.emailAddress = mainContact.Email;
            userContactAddress.city = mainContact.MailingCity;
            userContactAddress.country = mainContact.MailingCountry;
            userContactAddress.companyName = account.Name;
            userContactAddress.gender = mainContact.Gender__c;
            userContactAddress.houseNo = mainContact.HouseNumber__c;
            userContactAddress.phoneNumber = mainContact.Phone;
            userContactAddress.street = mainContact.MailingStreet;
            userContactAddress.zipCode = mainContact.MailingPostalCode;
            bookingRequest.request.userContactAddress = userContactAddress;
            bookingRequest.request.clearingHouse = account.ClearingHouse__c;
            bookingRequest.request.salesTeam = account.SalesTeam__c;
            bookingRequest.request.accountBookingType = account.BookingType__c;
            bookingRequest.request.billingTerms = account.BillingTerms__c;
            List<String> channelList = new List<String>();
            channelList.add(account.SalesChannel__c);
            bookingRequest.request.salesChannels = channelList;
            List<String> accessTypeList = new List<String>();
            accessTypeList.add(account.AccessType__c);
            bookingRequest.request.accountAccessTypes = accessTypeList;
            System.debug('After populating Account and Contact info in BookingRequest for opportunityId : '+opportunityId);
        } catch (Exception e) {
            LogUtil.insertDebugEvent('Booking Request Creation on Opportunity Stage Closed WON','Opportunity',opportunityId,e.getMessage(),'ERROR');
        }
    }

    @TestVisible
    public static void fillFeatureProductList(BookingRequest bookingRequest, List<FeatureProduct__c> featureProductList, Id opportunityId) {
        List<Product> products = new List<BookingInvoker.Product>();
        for(FeatureProduct__c featureProduct: featureProductList){
            Product product = new Product();
            product.enumValue = featureProduct.Type__c;
            product.price = Integer.valueOf(featureProduct.Price__c);
            product.pricePerMonth = Integer.valueOf(featureProduct.PricePerMonth__c);
            product.description = featureProduct.description__c;
            products.add(product);
        }
        bookingRequest.request.products = products;
    }

    @TestVisible
    public static void fillRevenueShareList(BookingRequest bookingRequest, List<RevenueShare__c> revenueShareList, Id opportunityId) {
        List<SmRevenueShare> smRevenueShares = new List<BookingInvoker.SmRevenueShare>();
        for(RevenueShare__c revenueShare: revenueShareList){
            SmRevenueShare smRevenueShare = new SmRevenueShare();
            smRevenueShare.salesManagerId = Integer.valueOf(revenueShare.SalesManagerId__c);
            smRevenueShare.profitCenter = revenueShare.ProfitCenter__c;
            smRevenueShare.totalShareInPercent = revenueShare.TotalShareInPercent__c;
            smRevenueShare.totalShareValue = revenueShare.TotalShareInPercent__c;
            smRevenueShares.add(smRevenueShare);
        }
        bookingRequest.request.smRevenueShares = smRevenueShares;
    }

    public static Integer invokeBookingAPI(BookingRequest bookingRequest){

        Http httpCls = new Http();
        HttpRequest request = createRequest();
        request.setBody(JSON.serialize(bookingRequest));
        HttpResponse response = httpCls.send(request);

        if(response.getStatusCode() == 200){
            System.debug('## Successfully retrieved Result' );
            System.debug('Response Body : '+response.getBody());
            BookingResponse bookingResponse = (BookingResponse) System.JSON.deserialize(response.getBody(), BookingResponse.class);
            return bookingResponse.bookingId;
        }
        else{
            system.debug('## Could not Booking API' );
            system.debug('## response status :' + response.getStatus());
            system.debug('## response message :' + response.getBody());
        }
        return -1;

    }


    public static HttpRequest createRequest() {
        List<SalesServiceAPISetting__mdt> salesServiceAPISettings = [SELECT SalesSvcURL__c FROM SalesServiceAPISetting__mdt LIMIT 1];
        SalesServiceAPISetting__mdt salesServiceAPISetting = salesServiceAPISettings.get(0);
        String url = salesServiceAPISetting.SalesSvcURL__c;

        HttpRequest req = new HttpRequest();
        req.setEndpoint(url);
        req.setMethod('POST');
        req.setTimeout(120000);

        req.setHeader('X-SEM-APP', 'sales'); //X-SEM-ENV
        req.setHeader('X-SEM-ENV', 'dev');
        req.setHeader('X-SEM-TOKEN', 'SGVsbG8gV29ybGQK');
        req.setHeader('Content-Type', 'application/json');

        return req;
    }

    global class BookingRequest {
        public RequestEntry request { get; set; }
    }



    global class SmRevenueShare {
        public Integer salesManagerId { get; set; }
        public String profitCenter { get; set; }
        public Double totalShareInPercent { get; set; }
        public Double totalShareValue { get; set; }
    }

    global class Product{
        public String enumValue { get; set; }
        public Integer price { get; set; }
        public Integer pricePerMonth { get; set; }
        public String description { get; set; }
    }

    global class UserContactAddress {
        public String firstname { get; set; }
        public String lastname { get; set; }
        public String gender { get; set; }
        public String companyName { get; set; }
        public String phoneNumber { get; set; }
        public String emailAddress { get; set; }
        public String country { get; set; }
        public String city { get; set; }
        public String zipCode { get; set; }
        public String street { get; set; }
        public String houseNo { get; set; }
    }

    global class RequestEntry {
        public Integer requesterId { get; set; }
        public Integer userId { get; set; }
        public UserContactAddress userContactAddress { get; set; }
        public String clearingHouse { get; set; }
        public String liableOffice { get; set; }
        public String salesTeam { get; set; }
        public Integer salesManagerId { get; set; }
        public String accountBookingType { get; set; }
        public String billingTerms { get; set; }
        public List<String> salesChannels { get; set; }
        public List<String> accountAccessTypes { get; set; }
        public String agreementForm { get; set; }
        public List<Product> products { get; set; }
        public String dealType { get; set; }
        public String salesforceOpportunityId { get; set; }
        public List<SmRevenueShare> smRevenueShares { get; set; }
    }

    global class BookingResponse {
        public Integer bookingId { get; set; }
    }

}