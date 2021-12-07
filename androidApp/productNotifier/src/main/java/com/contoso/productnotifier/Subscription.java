package com.contoso.productnotifier;

import java.util.Date;
import java.util.UUID;

public class Subscription {

    private String id;
    private String deviceToken;
    private String category;
    private String action;
    private Date createdAt;

    public Subscription() {
        Date date = new Date();
        this.setCreatedAt(date);
        this.id = UUID.randomUUID().toString();
    }

    public void setId(String value) { this.id = value; }

    public String getId() { return this. id; }

    public void setDeviceToken(String value) {
        this.deviceToken = value;
    }

    public String getDeviceToken() {
        return this.deviceToken;
    }

    public void setCategory(String value) {
        this.category = value;
    }

    public String getCategory() {
        return this.category;
    }

    public void setAction(String value) {
        this.action = value;
    }

    public String getAction() {
        return this.action;
    }

    public void setCreatedAt(Date value) { this.createdAt = value; }

}
