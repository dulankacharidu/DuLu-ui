package v2ui

import (
	"fmt"
	"DuLu-ui/config"
	"DuLu-ui/database"
	"DuLu-ui/database/model"
	"DuLu-ui/util/common"
	"DuLu-ui/web/service"
)

func MigrateFromV2UI(dbPath string) error {
	err := initDB(dbPath)
	if err != nil {
		return common.NewError("init v2-ui database failed:", err)
	}
	err = database.InitDB(config.GetDBPath())
	if err != nil {
		return common.NewError("init DuLu-ui database failed:", err)
	}

	v2Inbounds, err := getV2Inbounds()
	if err != nil {
		return common.NewError("get v2-ui inbounds failed:", err)
	}
	if len(v2Inbounds) == 0 {
		fmt.Println("migrate v2-ui inbounds success: 0")
		return nil
	}

	userService := service.UserService{}
	user, err := userService.GetFirstUser()
	if err != nil {
		return common.NewError("get DuLu-ui user failed:", err)
	}

	inbounds := make([]*model.Inbound, 0)
	for _, v2inbound := range v2Inbounds {
		inbounds = append(inbounds, v2inbound.ToInbound(user.Id))
	}

	inboundService := service.InboundService{}
	err = inboundService.AddInbounds(inbounds)
	if err != nil {
		return common.NewError("add DuLu-ui inbounds failed:", err)
	}

	fmt.Println("migrate v2-ui inbounds success:", len(inbounds))

	return nil
}
