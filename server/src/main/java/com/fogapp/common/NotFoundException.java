package com.fogapp.common;

public class NotFoundException extends RuntimeException {

    public NotFoundException(String resourceName, Long id) {
        super(resourceName + " 정보를 찾을 수 없습니다. (id=" + id + ")");
    }
}
