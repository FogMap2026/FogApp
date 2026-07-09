package com.fogapp.match;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

/**
 * 매칭(동행 요청) CRUD 뼈대(#1-8). 성향 유사도 계산(3-8)은 이후 score 채우기로 이어진다.
 */
@RestController
@RequestMapping("/api/matches")
public class MatchController {

    private final MatchService matchService;

    public MatchController(MatchService matchService) {
        this.matchService = matchService;
    }

    @PostMapping
    public ResponseEntity<MatchResponse> create(@Valid @RequestBody MatchCreateRequest request) {
        Match match = matchService.request(request.requesterId(), request.addresseeId());
        return ResponseEntity.status(HttpStatus.CREATED).body(MatchResponse.from(match));
    }

    @GetMapping("/{id}")
    public MatchResponse get(@PathVariable Long id) {
        return MatchResponse.from(matchService.get(id));
    }

    @GetMapping
    public List<MatchResponse> listForUser(@RequestParam Long userId) {
        return matchService.listForUser(userId).stream().map(MatchResponse::from).toList();
    }

    @PatchMapping("/{id}/status")
    public MatchResponse updateStatus(@PathVariable Long id, @Valid @RequestBody MatchStatusUpdateRequest request) {
        return MatchResponse.from(matchService.updateStatus(id, request.status()));
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        matchService.delete(id);
        return ResponseEntity.noContent().build();
    }
}
