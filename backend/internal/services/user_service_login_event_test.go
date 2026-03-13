package services

import (
	"backend/internal/dto"
	"backend/internal/models"
	"backend/pkg/utils/crypto"
	"backend/pkg/utils/jwt"
	"backend/pkg/utils/logger"
	"context"
	"encoding/json"
	"errors"
	"sync"
	"testing"

	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
)

type mockUserRepository struct {
	mock.Mock
}

var loggerInitOnce sync.Once

func ensureLoggerInitialized() {
	loggerInitOnce.Do(func() {
		logger.Init()
		_ = jwt.SetDefaultSecret("test-jwt-secret-key-abcdefghijklmnopqrstuvwxyz")
	})
}

func (m *mockUserRepository) Create(ctx context.Context, user *models.User) (*models.User, error) {
	args := m.Called(ctx, user)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.User), args.Error(1)
}

func (m *mockUserRepository) FindByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.User), args.Error(1)
}

func (m *mockUserRepository) FindByUsername(ctx context.Context, username string) (*models.User, error) {
	args := m.Called(ctx, username)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.User), args.Error(1)
}

func (m *mockUserRepository) FindByEmail(ctx context.Context, email string) (*models.User, error) {
	args := m.Called(ctx, email)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.User), args.Error(1)
}

func (m *mockUserRepository) Update(ctx context.Context, user *models.User) (*models.User, error) {
	args := m.Called(ctx, user)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*models.User), args.Error(1)
}

func (m *mockUserRepository) Delete(ctx context.Context, id uuid.UUID) error {
	args := m.Called(ctx, id)
	return args.Error(0)
}

func (m *mockUserRepository) List(ctx context.Context) ([]*models.User, error) {
	args := m.Called(ctx)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]*models.User), args.Error(1)
}

type mockMenuRepository struct {
	mock.Mock
}

func (m *mockMenuRepository) FindByRoleIDs(ctx context.Context, roleIDs []uuid.UUID) ([]*models.Menu, error) {
	args := m.Called(ctx, roleIDs)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]*models.Menu), args.Error(1)
}

func (m *mockMenuRepository) FindAll(ctx context.Context) ([]*models.Menu, error) {
	args := m.Called(ctx)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]*models.Menu), args.Error(1)
}

type mockPublisher struct {
	mock.Mock
}

func (m *mockPublisher) Publish(ctx context.Context, key string, payload []byte) error {
	args := m.Called(ctx, key, payload)
	return args.Error(0)
}

func (m *mockPublisher) HealthCheck(ctx context.Context) error {
	args := m.Called(ctx)
	return args.Error(0)
}

func (m *mockPublisher) Close() error {
	args := m.Called()
	return args.Error(0)
}

func TestLogin_PublishLoginEvent(t *testing.T) {
	ensureLoggerInitialized()

	ctx := context.Background()
	userRepo := new(mockUserRepository)
	menuRepo := new(mockMenuRepository)
	publisher := new(mockPublisher)

	hashed, err := crypto.BcryptHash("secret123", 10)
	assert.NoError(t, err)

	uid := uuid.New()
	user := &models.User{
		ID:       uid,
		Username: "alice",
		Email:    "alice@example.com",
		Password: hashed,
		Role:     "user",
	}

	userRepo.On("FindByUsername", ctx, "alice").Return(user, nil).Once()
	publisher.On("Publish", ctx, uid.String(), mock.MatchedBy(func(payload []byte) bool {
		var event map[string]any
		if err := json.Unmarshal(payload, &event); err != nil {
			return false
		}
		return event["event"] == "user.login" && event["username"] == "alice"
	})).Return(nil).Once()

	service := NewUserService(userRepo, menuRepo, publisher)
	resp, loginErr := service.Login(ctx, &dto.LoginRequest{
		Username: "alice",
		Password: "secret123",
	})

	assert.NoError(t, loginErr)
	assert.NotNil(t, resp)
	assert.NotEmpty(t, resp.Token)
	publisher.AssertExpectations(t)
	userRepo.AssertExpectations(t)
}

func TestLogin_WhenPublishFails_LoginStillSucceeds(t *testing.T) {
	ensureLoggerInitialized()

	ctx := context.Background()
	userRepo := new(mockUserRepository)
	menuRepo := new(mockMenuRepository)
	publisher := new(mockPublisher)

	hashed, err := crypto.BcryptHash("secret123", 10)
	assert.NoError(t, err)

	uid := uuid.New()
	user := &models.User{
		ID:       uid,
		Username: "bob",
		Email:    "bob@example.com",
		Password: hashed,
		Role:     "user",
	}

	userRepo.On("FindByUsername", ctx, "bob").Return(user, nil).Once()
	publisher.On("Publish", ctx, uid.String(), mock.AnythingOfType("[]uint8")).Return(errors.New("kafka write failed")).Once()

	service := NewUserService(userRepo, menuRepo, publisher)
	resp, loginErr := service.Login(ctx, &dto.LoginRequest{
		Username: "bob",
		Password: "secret123",
	})

	assert.NoError(t, loginErr)
	assert.NotNil(t, resp)
	assert.NotEmpty(t, resp.Token)
	publisher.AssertExpectations(t)
	userRepo.AssertExpectations(t)
}
