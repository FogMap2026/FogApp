package com.fogapp.push;

import java.util.List;

import org.springframework.data.jpa.repository.JpaRepository;

public interface DeviceTokenRepository extends JpaRepository<DeviceToken, String> {

    List<DeviceToken> findAllByUserId(Long userId);

    void deleteByTokenAndUserId(String token, Long userId);
}
