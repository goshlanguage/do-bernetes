clean:
	terraform destroy -auto-approve
	rm -vf plan.out terraform.tfstate
	find $(CURDIR)/secrets/ -type f -delete

deploy:
	terraform plan -out plan.out
	terraform apply "plan.out" -auto-approve
