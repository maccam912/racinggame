package directory

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// DailyLog accepts structured service events only. The total service/worker log
// has a 100 MiB daily ceiling and seven-day retention; bodies/tokens/IPs are never
// passed to this writer.
type DailyLog struct {
	mu          sync.Mutex
	folder, day string
	file        *os.File
	size        int64
	Now         func() time.Time
}

func NewDailyLog(folder string) (*DailyLog, error) {
	if err := os.MkdirAll(folder, 0700); err != nil {
		return nil, err
	}
	return &DailyLog{folder: folder, Now: time.Now}, nil
}
func (l *DailyLog) Write(value []byte) (int, error) {
	l.mu.Lock()
	defer l.mu.Unlock()
	now := l.Now().UTC()
	day := now.Format("2006-01-02")
	if l.day != day {
		if l.file != nil {
			l.file.Close()
		}
		file, err := os.OpenFile(filepath.Join(l.folder, day+".jsonl"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0600)
		if err != nil {
			return 0, err
		}
		info, err := file.Stat()
		if err != nil {
			file.Close()
			return 0, err
		}
		l.file = file
		l.day = day
		l.size = info.Size()
		entries, _ := os.ReadDir(l.folder)
		for _, entry := range entries {
			if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".jsonl") {
				continue
			}
			date, err := time.Parse("2006-01-02", strings.TrimSuffix(entry.Name(), ".jsonl"))
			if err == nil && date.Before(now.Truncate(24*time.Hour).AddDate(0, 0, -6)) {
				_ = os.Remove(filepath.Join(l.folder, entry.Name()))
			}
		}
	}
	if l.size+int64(len(value)) > 100*1024*1024 {
		return len(value), nil
	}
	written, err := l.file.Write(value)
	l.size += int64(written)
	return written, err
}
func (l *DailyLog) Close() error {
	l.mu.Lock()
	defer l.mu.Unlock()
	if l.file == nil {
		return nil
	}
	err := l.file.Close()
	l.file = nil
	l.day = ""
	return err
}
func (s *Store) Ban(ctxGuest string, banned bool) error {
	if !validUUID(ctxGuest) {
		return errors.New("invalid guest ID")
	}
	tx, err := s.db.Begin()
	if err != nil {
		return err
	}
	defer tx.Rollback()
	result, err := tx.Exec(`UPDATE guests SET banned=? WHERE id=?`, banned, ctxGuest)
	if err != nil {
		return err
	}
	count, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if count == 0 {
		return errors.New("guest not found")
	}
	if banned {
		if _, err = tx.Exec(`INSERT OR IGNORE INTO worker_commands(id,worker,kind,guest,created) SELECT lower(hex(randomblob(16))),w.id,'leave',?,? FROM workers w JOIN rooms r ON r.worker=w.id`, ctxGuest, time.Now().Unix()); err != nil {
			return err
		}
	}
	return tx.Commit()
}
